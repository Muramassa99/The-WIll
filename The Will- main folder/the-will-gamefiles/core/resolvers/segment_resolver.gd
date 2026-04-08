extends RefCounted
class_name SegmentResolver

const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")
const MaterialRuntimeResolverScript = preload("res://core/resolvers/material_runtime_resolver.gd")

var forge_rules: ForgeRulesDef = DEFAULT_FORGE_RULES_RESOURCE
var material_runtime_resolver = MaterialRuntimeResolverScript.new()

func _init(rules: ForgeRulesDef = null) -> void:
	forge_rules = rules if rules != null else DEFAULT_FORGE_RULES_RESOURCE

func resolve_segments(cells: Array[CellAtom], material_lookup: Dictionary = {}) -> Array[SegmentAtom]:
	var cell_lookup: Dictionary[Vector3i, CellAtom] = _build_cell_lookup(cells)
	var visited: Dictionary[Vector3i, bool] = {}
	var resolved_segments: Array[SegmentAtom] = []

	for position_value in cell_lookup.keys():
		var position: Vector3i = position_value
		if visited.get(position, false):
			continue
		var member_cells: Array[CellAtom] = _collect_connected_cells(position, cell_lookup, visited)
		if member_cells.is_empty():
			continue

		var segment: SegmentAtom = SegmentAtom.new()
		segment.segment_id = StringName("segment_%d" % resolved_segments.size())
		segment.member_cells = member_cells
		segment.material_mix = _build_material_mix(member_cells)
		_populate_segment_metadata(segment, material_lookup)
		resolved_segments.append(segment)

	return resolved_segments

func _build_cell_lookup(cells: Array[CellAtom]) -> Dictionary[Vector3i, CellAtom]:
	var lookup: Dictionary[Vector3i, CellAtom] = {}
	for cell: CellAtom in cells:
		if cell == null:
			continue
		lookup[cell.grid_position] = cell
	return lookup

func _collect_connected_cells(
		start_position: Vector3i,
		cell_lookup: Dictionary[Vector3i, CellAtom],
		visited: Dictionary[Vector3i, bool]
	) -> Array[CellAtom]:
	var pending: Array[Vector3i] = [start_position]
	var member_cells: Array[CellAtom] = []

	while not pending.is_empty():
		var current_position: Vector3i = pending.pop_back()
		if visited.get(current_position, false):
			continue
		visited[current_position] = true

		var current_cell: CellAtom = cell_lookup.get(current_position)
		if current_cell == null:
			continue

		member_cells.append(current_cell)
		for neighbor_offset in _get_neighbor_offsets():
			var neighbor_position: Vector3i = current_position + neighbor_offset
			if visited.get(neighbor_position, false):
				continue
			if cell_lookup.has(neighbor_position):
				pending.append(neighbor_position)

	return member_cells

func _build_material_mix(member_cells: Array[CellAtom]) -> Dictionary:
	var material_mix: Dictionary = {}
	for cell: CellAtom in member_cells:
		var material_variant_id: StringName = cell.material_variant_id
		var existing_count: int = material_mix.get(material_variant_id, 0)
		material_mix[material_variant_id] = existing_count + 1
	return material_mix

func _populate_segment_metadata(segment: SegmentAtom, material_lookup: Dictionary) -> void:
	if segment == null or segment.member_cells.is_empty():
		return

	var bounds: Dictionary = _build_segment_bounds(segment.member_cells)
	var major_axis: Vector3i = _resolve_major_axis(bounds)
	var minor_axes: Array[Vector3i] = _resolve_minor_axes(major_axis)
	var cross_section_data: Dictionary = _build_cross_section_data(segment.member_cells, major_axis, minor_axes)

	segment.major_axis = major_axis
	segment.minor_axis_a = minor_axes[0]
	segment.minor_axis_b = minor_axes[1]
	segment.length_voxels = _get_axis_span(bounds, major_axis)
	segment.cross_width_voxels = cross_section_data.get("max_width", 0)
	segment.cross_thickness_voxels = cross_section_data.get("max_thickness", 0)
	segment.anchor_material_ratio = _calculate_support_ratio(segment.member_cells, material_lookup, &"anchor")
	segment.joint_support_material_ratio = _calculate_support_ratio(segment.member_cells, material_lookup, &"joint")
	segment.bow_string_material_ratio = _calculate_support_ratio(segment.member_cells, material_lookup, &"bow_string")
	segment.start_slice_anchor_valid = _is_slice_anchor_valid(
		cross_section_data.get("first_slice", -1),
		segment.member_cells,
		major_axis,
		material_lookup
	)
	segment.end_slice_anchor_valid = _is_slice_anchor_valid(
		cross_section_data.get("last_slice", -1),
		segment.member_cells,
		major_axis,
		material_lookup
	)
	segment.profile_state = _resolve_profile_state(cross_section_data)
	segment.has_opposing_bevel_pair = cross_section_data.get("all_slices_have_opposing_bevel_pairs", false)
	_apply_first_pass_role_hints(segment, material_lookup)

func _apply_first_pass_role_hints(segment: SegmentAtom, material_lookup: Dictionary) -> void:
	if segment == null:
		return
	# Current first-pass rule: SegmentResolver only emits broad bow-related role hints here.
	# Limb assignment and any later non-bow role system remain separate follow-on resolvers.
	segment.edge_span_overlap = false
	segment.is_riser_candidate = _is_riser_candidate(segment, material_lookup)
	segment.is_bow_string_candidate = _is_bow_string_candidate(segment, material_lookup)
	segment.projectile_pass_candidate = _is_projectile_pass_candidate(segment, material_lookup)
	segment.is_upper_limb_candidate = false
	segment.is_lower_limb_candidate = false

func _build_segment_bounds(member_cells: Array[CellAtom]) -> Dictionary:
	var first_position: Vector3i = member_cells[0].grid_position
	var min_position: Vector3i = first_position
	var max_position: Vector3i = first_position

	for cell: CellAtom in member_cells:
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

func _resolve_major_axis(bounds: Dictionary) -> Vector3i:
	var min_position: Vector3i = bounds.get("min", Vector3i.ZERO)
	var max_position: Vector3i = bounds.get("max", Vector3i.ZERO)
	var x_span: int = (max_position.x - min_position.x) + 1
	var y_span: int = (max_position.y - min_position.y) + 1
	var z_span: int = (max_position.z - min_position.z) + 1

	if y_span > x_span and y_span >= z_span:
		return Vector3i.UP
	if z_span > x_span and z_span > y_span:
		return Vector3i.BACK
	return Vector3i.RIGHT

func _resolve_minor_axes(major_axis: Vector3i) -> Array[Vector3i]:
	if major_axis == Vector3i.UP:
		return [Vector3i.RIGHT, Vector3i.BACK]
	if major_axis == Vector3i.BACK:
		return [Vector3i.RIGHT, Vector3i.UP]
	return [Vector3i.UP, Vector3i.BACK]

func _build_cross_section_data(
		member_cells: Array[CellAtom],
		major_axis: Vector3i,
		minor_axes: Array[Vector3i]
	) -> Dictionary:
	var slice_metrics: Dictionary = {}
	var first_slice: int = 2147483647
	var last_slice: int = -2147483648

	for cell: CellAtom in member_cells:
		if cell == null:
			continue
		var slice_index: int = _get_axis_component(cell.grid_position, major_axis)
		var minor_a_value: int = _get_axis_component(cell.grid_position, minor_axes[0])
		var minor_b_value: int = _get_axis_component(cell.grid_position, minor_axes[1])

		first_slice = mini(first_slice, slice_index)
		last_slice = maxi(last_slice, slice_index)

		if not slice_metrics.has(slice_index):
			slice_metrics[slice_index] = {
				"min_a": minor_a_value,
				"max_a": minor_a_value,
				"min_b": minor_b_value,
				"max_b": minor_b_value,
				"count": 0,
				"occupied": {},
			}

		var metric: Dictionary = slice_metrics[slice_index]
		metric["min_a"] = mini(metric.get("min_a", minor_a_value), minor_a_value)
		metric["max_a"] = maxi(metric.get("max_a", minor_a_value), minor_a_value)
		metric["min_b"] = mini(metric.get("min_b", minor_b_value), minor_b_value)
		metric["max_b"] = maxi(metric.get("max_b", minor_b_value), minor_b_value)
		metric["count"] = metric.get("count", 0) + 1
		var occupied: Dictionary = metric.get("occupied", {})
		occupied[Vector2i(minor_a_value, minor_b_value)] = true
		metric["occupied"] = occupied
		slice_metrics[slice_index] = metric

	var max_width: int = 0
	var max_thickness: int = 0
	var all_slices_are_full_rectangles: bool = not slice_metrics.is_empty()
	var all_slices_have_opposing_bevel_pairs: bool = not slice_metrics.is_empty()
	for metric_value in slice_metrics.values():
		var metric: Dictionary = metric_value
		var width: int = (metric.get("max_a", 0) - metric.get("min_a", 0)) + 1
		var thickness: int = (metric.get("max_b", 0) - metric.get("min_b", 0)) + 1
		var expected_cell_count: int = width * thickness
		max_width = maxi(max_width, width)
		max_thickness = maxi(max_thickness, thickness)
		if metric.get("count", 0) != expected_cell_count:
			all_slices_are_full_rectangles = false
		if not _slice_has_opposing_bevel_pair(metric):
			all_slices_have_opposing_bevel_pairs = false

	if slice_metrics.is_empty():
		first_slice = -1
		last_slice = -1

	return {
		"slice_metrics": slice_metrics,
		"first_slice": first_slice,
		"last_slice": last_slice,
		"max_width": max_width,
		"max_thickness": max_thickness,
		"all_slices_are_full_rectangles": all_slices_are_full_rectangles,
		"all_slices_have_opposing_bevel_pairs": all_slices_have_opposing_bevel_pairs,
	}

func _slice_has_opposing_bevel_pair(metric: Dictionary) -> bool:
	var min_a: int = metric.get("min_a", 0)
	var max_a: int = metric.get("max_a", 0)
	var min_b: int = metric.get("min_b", 0)
	var max_b: int = metric.get("max_b", 0)
	var width: int = (max_a - min_a) + 1
	var thickness: int = (max_b - min_b) + 1
	var expected_cell_count: int = width * thickness
	if width < 3 or thickness < 2:
		return false
	if metric.get("count", 0) != expected_cell_count - 2:
		return false

	var occupied: Dictionary = metric.get("occupied", {})
	var diagonal_a_missing: bool = not occupied.has(Vector2i(min_a, min_b)) and not occupied.has(Vector2i(max_a, max_b))
	var diagonal_b_missing: bool = not occupied.has(Vector2i(min_a, max_b)) and not occupied.has(Vector2i(max_a, min_b))
	return diagonal_a_missing or diagonal_b_missing

func _get_axis_span(bounds: Dictionary, axis: Vector3i) -> int:
	var min_position: Vector3i = bounds.get("min", Vector3i.ZERO)
	var max_position: Vector3i = bounds.get("max", Vector3i.ZERO)
	return (_get_axis_component(max_position, axis) - _get_axis_component(min_position, axis)) + 1

func _get_axis_component(value: Vector3i, axis: Vector3i) -> int:
	if axis == Vector3i.UP:
		return value.y
	if axis == Vector3i.BACK:
		return value.z
	return value.x

func _calculate_support_ratio(member_cells: Array[CellAtom], material_lookup: Dictionary, support_type: StringName) -> float:
	if member_cells.is_empty():
		return 0.0

	var supporting_cell_count: int = 0
	for cell: CellAtom in member_cells:
		var base_material: BaseMaterialDef = _resolve_base_material_for_cell(cell, material_lookup)
		if _supports_type(base_material, support_type):
			supporting_cell_count += 1

	return float(supporting_cell_count) / float(member_cells.size())

func _is_slice_anchor_valid(
		slice_index: int,
		member_cells: Array[CellAtom],
		major_axis: Vector3i,
		material_lookup: Dictionary
	) -> bool:
	if slice_index < 0:
		return false

	var found_cell: bool = false
	for cell: CellAtom in member_cells:
		if cell == null:
			continue
		if _get_axis_component(cell.grid_position, major_axis) != slice_index:
			continue
		found_cell = true
		var base_material: BaseMaterialDef = _resolve_base_material_for_cell(cell, material_lookup)
		if not _supports_type(base_material, &"anchor"):
			return false

	return found_cell

func _resolve_profile_state(cross_section_data: Dictionary) -> StringName:
	if cross_section_data.get("all_slices_have_opposing_bevel_pairs", false):
		return &"beveled_blade"
	if cross_section_data.get("all_slices_are_full_rectangles", false):
		return &"square"
	return &""

func _resolve_base_material_for_cell(cell: CellAtom, material_lookup: Dictionary) -> BaseMaterialDef:
	return material_runtime_resolver.resolve_base_material_for_cell(cell, material_lookup)

func _supports_type(base_material: BaseMaterialDef, support_type: StringName) -> bool:
	if base_material == null:
		return false
	match support_type:
		&"anchor":
			return base_material.can_be_anchor_material or base_material.can_be_grip_profile
		&"joint":
			return base_material.supports_joint()
		&"bow_limb":
			return base_material.can_be_bow_limb
		&"bow_string":
			return base_material.supports_bow_string()
		&"riser":
			return base_material.can_be_riser_core or base_material.can_be_bow_grip
		&"projectile":
			return base_material.can_be_projectile_support or base_material.can_be_bow_grip
		_:
			return false

func _is_riser_candidate(segment: SegmentAtom, material_lookup: Dictionary) -> bool:
	if segment == null:
		return false
	var rules: ForgeRulesDef = forge_rules
	var riser_ratio: float = _calculate_support_ratio(segment.member_cells, material_lookup, &"riser")
	var compact_cross_section: bool = maxi(segment.cross_width_voxels, segment.cross_thickness_voxels) >= rules.riser_min_compact_cross_span_voxels
	return riser_ratio >= rules.riser_min_support_material_ratio and compact_cross_section and segment.length_voxels <= rules.riser_max_length_voxels

func _is_bow_string_candidate(segment: SegmentAtom, material_lookup: Dictionary) -> bool:
	if segment == null:
		return false
	var rules: ForgeRulesDef = forge_rules
	var string_ratio: float = _calculate_support_ratio(segment.member_cells, material_lookup, &"bow_string")
	return string_ratio >= rules.bow_string_min_support_material_ratio and maxi(segment.cross_width_voxels, segment.cross_thickness_voxels) <= rules.bow_string_max_cross_span_voxels and segment.length_voxels >= rules.bow_string_min_length_voxels

func _is_projectile_pass_candidate(segment: SegmentAtom, material_lookup: Dictionary) -> bool:
	if segment == null:
		return false
	var rules: ForgeRulesDef = forge_rules
	var projectile_ratio: float = _calculate_support_ratio(segment.member_cells, material_lookup, &"projectile")
	return projectile_ratio >= rules.projectile_min_support_material_ratio or segment.is_riser_candidate

func _get_neighbor_offsets() -> Array[Vector3i]:
	return [
		Vector3i.LEFT,
		Vector3i.RIGHT,
		Vector3i.UP,
		Vector3i.DOWN,
		Vector3i.FORWARD,
		Vector3i.BACK,
	]
