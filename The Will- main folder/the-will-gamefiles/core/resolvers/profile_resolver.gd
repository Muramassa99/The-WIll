extends RefCounted
class_name ProfileResolver

const MaterialRuntimeResolverScript = preload("res://core/resolvers/material_runtime_resolver.gd")

var anchor_resolver: AnchorResolver = AnchorResolver.new()
var shape_classifier_resolver: ShapeClassifierResolver = ShapeClassifierResolver.new()
var material_runtime_resolver = MaterialRuntimeResolverScript.new()

func bake_profile(
		cells: Array[CellAtom],
		segments: Array[SegmentAtom],
		anchors: Array[AnchorAtom],
		material_lookup: Dictionary = {},
		_shape_data: Dictionary = {},
		joint_data: Dictionary = {},
		bow_data: Dictionary = {}
	) -> BakedProfile:
	var profile: BakedProfile = BakedProfile.new()
	profile.total_mass = _calculate_total_mass(cells, material_lookup)
	profile.center_of_mass = _calculate_center_of_mass(cells, material_lookup, profile.total_mass)
	if not _is_connectivity_valid(cells, segments):
		profile.validation_error = "disconnected_islands"

	var primary_grip: AnchorAtom = _find_primary_grip_anchor(anchors, profile.center_of_mass)
	profile.primary_grip_valid = primary_grip != null
	if primary_grip != null:
		var grip_contact_position: Vector3 = anchor_resolver.resolve_primary_grip_contact_position(primary_grip, profile.center_of_mass)
		var forward_axis: Vector3 = _resolve_forward_axis(primary_grip)
		profile.primary_grip_contact_position = grip_contact_position
		profile.primary_grip_span_start = primary_grip.span_start_local_position
		profile.primary_grip_span_end = primary_grip.span_end_local_position
		profile.primary_grip_span_length_voxels = primary_grip.span_length
		profile.primary_grip_slide_axis = forward_axis
		profile.primary_grip_offset = anchor_resolver.calculate_primary_grip_offset(
			profile.center_of_mass,
			grip_contact_position
		)
		profile.reach = _calculate_reach(cells, grip_contact_position)
		profile.front_heavy_score = _calculate_front_heavy_score(
			profile.primary_grip_offset,
			forward_axis,
			profile.reach
		)
		profile.balance_score = _calculate_balance_score(profile.primary_grip_offset, profile.reach)
	elif profile.validation_error.is_empty():
		profile.validation_error = "no_primary_grip_candidate"

	profile.edge_score = _calculate_edge_score(segments, material_lookup)
	profile.blunt_score = _calculate_blunt_score(segments, material_lookup)
	profile.pierce_score = _calculate_pierce_score(segments, material_lookup)
	profile.guard_score = _calculate_guard_score(segments, material_lookup)
	profile.flex_score = _calculate_flex_score(segments, material_lookup, joint_data, bow_data)
	profile.launch_score = _calculate_launch_score(segments, material_lookup, bow_data)
	return profile

func _is_connectivity_valid(cells: Array[CellAtom], segments: Array[SegmentAtom]) -> bool:
	if cells.is_empty():
		return true
	if segments.size() != 1:
		return false
	var primary_segment: SegmentAtom = segments[0]
	if primary_segment == null:
		return false
	return primary_segment.member_cells.size() == cells.size()

func _calculate_total_mass(
		cells: Array[CellAtom],
		material_lookup: Dictionary
	) -> float:
	var total_mass: float = 0.0
	for cell: CellAtom in cells:
		total_mass += _get_cell_mass(cell, material_lookup)
	return total_mass

func _calculate_center_of_mass(
		cells: Array[CellAtom],
		material_lookup: Dictionary,
		total_mass: float
	) -> Vector3:
	if total_mass <= 0.0:
		return Vector3.ZERO

	var weighted_position_sum: Vector3 = Vector3.ZERO
	for cell: CellAtom in cells:
		var cell_mass: float = _get_cell_mass(cell, material_lookup)
		weighted_position_sum += cell.get_center_position() * cell_mass

	return weighted_position_sum / total_mass

func _get_cell_mass(
		cell: CellAtom,
		material_lookup: Dictionary
	) -> float:
	return material_runtime_resolver.resolve_density_per_cell(cell, material_lookup)

func _find_primary_grip_anchor(anchors: Array[AnchorAtom], center_of_mass: Vector3 = Vector3.ZERO) -> AnchorAtom:
	var best_anchor: AnchorAtom = null
	var best_distance_squared: float = INF
	var best_span_length: int = -1
	for anchor: AnchorAtom in anchors:
		if anchor == null:
			continue
		if anchor.anchor_type != "primary_grip":
			continue
		var candidate_position: Vector3 = anchor_resolver.resolve_primary_grip_contact_position(anchor, center_of_mass)
		var distance_squared: float = candidate_position.distance_squared_to(center_of_mass)
		var candidate_span_length: int = maxi(anchor.span_length, 0)
		if best_anchor == null or distance_squared < best_distance_squared - 0.00001:
			best_anchor = anchor
			best_distance_squared = distance_squared
			best_span_length = candidate_span_length
			continue
		if is_equal_approx(distance_squared, best_distance_squared) and candidate_span_length > best_span_length:
			best_anchor = anchor
			best_span_length = candidate_span_length
	return best_anchor

func _resolve_forward_axis(primary_grip: AnchorAtom) -> Vector3:
	if primary_grip == null:
		return Vector3.ZERO
	if primary_grip.local_axis == Vector3.ZERO:
		return Vector3.ZERO
	return primary_grip.local_axis.normalized()

func _calculate_reach(cells: Array[CellAtom], primary_grip_position: Vector3) -> float:
	var max_distance: float = 0.0
	for cell: CellAtom in cells:
		if cell == null:
			continue
		var distance: float = primary_grip_position.distance_to(cell.get_center_position())
		if distance > max_distance:
			max_distance = distance
	return max_distance

func _calculate_front_heavy_score(primary_grip_offset: Vector3, forward_axis: Vector3, reach: float) -> float:
	if forward_axis == Vector3.ZERO:
		return 0.0
	var epsilon: float = 0.00001
	var safe_reach: float = maxf(reach, epsilon)
	var projected_offset: float = primary_grip_offset.dot(forward_axis)
	return clampf(projected_offset / safe_reach, -1.0, 1.0)

func _calculate_balance_score(primary_grip_offset: Vector3, reach: float) -> float:
	var epsilon: float = 0.00001
	var safe_reach: float = maxf(reach, epsilon)
	return 1.0 - clampf(primary_grip_offset.length() / safe_reach, 0.0, 1.0)

func _calculate_blunt_score(segments: Array[SegmentAtom], material_lookup: Dictionary) -> float:
	var total_segment_mass: float = _calculate_total_segment_mass(segments, material_lookup)
	if total_segment_mass <= 0.0:
		return 0.0

	var blunt_score: float = 0.0
	for segment: SegmentAtom in segments:
		if not shape_classifier_resolver.is_blunt_valid_segment(segment):
			continue
		var segment_mass_ratio: float = _calculate_segment_mass(segment, material_lookup) / total_segment_mass
		var blunt_material_ratio: float = _calculate_material_support_ratio(segment, material_lookup, &"blunt")
		blunt_score += segment_mass_ratio * blunt_material_ratio

	return clampf(blunt_score, 0.0, 1.0)

func _calculate_edge_score(segments: Array[SegmentAtom], material_lookup: Dictionary) -> float:
	var total_segment_mass: float = _calculate_total_segment_mass(segments, material_lookup)
	if total_segment_mass <= 0.0:
		return 0.0

	var edge_score: float = 0.0
	for segment: SegmentAtom in segments:
		if not shape_classifier_resolver.is_edge_valid_segment(segment):
			continue
		var segment_mass_ratio: float = _calculate_segment_mass(segment, material_lookup) / total_segment_mass
		var edge_material_ratio: float = _calculate_material_support_ratio(segment, material_lookup, &"edge")
		edge_score += segment_mass_ratio * edge_material_ratio

	return clampf(edge_score, 0.0, 1.0)

func _calculate_guard_score(segments: Array[SegmentAtom], material_lookup: Dictionary) -> float:
	var total_segment_mass: float = _calculate_total_segment_mass(segments, material_lookup)
	if total_segment_mass <= 0.0:
		return 0.0

	var guard_score: float = 0.0
	for segment: SegmentAtom in segments:
		var guard_span_score: float = shape_classifier_resolver.get_guard_span_score(segment)
		if guard_span_score <= 0.0:
			continue
		var segment_mass_ratio: float = _calculate_segment_mass(segment, material_lookup) / total_segment_mass
		var guard_material_ratio: float = _calculate_material_support_ratio(segment, material_lookup, &"guard")
		guard_score += segment_mass_ratio * guard_span_score * guard_material_ratio

	return clampf(guard_score, 0.0, 1.0)

func _calculate_pierce_score(segments: Array[SegmentAtom], material_lookup: Dictionary) -> float:
	var total_segment_mass: float = _calculate_total_segment_mass(segments, material_lookup)
	if total_segment_mass <= 0.0:
		return 0.0

	var pierce_score: float = 0.0
	for segment: SegmentAtom in segments:
		var tip_hint_score: float = shape_classifier_resolver.get_pierce_tip_hint_score(segment)
		if tip_hint_score <= 0.0:
			continue
		var segment_mass_ratio: float = _calculate_segment_mass(segment, material_lookup) / total_segment_mass
		var pierce_material_ratio: float = _calculate_material_support_ratio(segment, material_lookup, &"pierce")
		pierce_score += segment_mass_ratio * tip_hint_score * pierce_material_ratio

	return clampf(pierce_score, 0.0, 1.0)

func _calculate_flex_score(
		segments: Array[SegmentAtom],
		material_lookup: Dictionary,
		joint_data: Dictionary,
		bow_data: Dictionary
	) -> float:
	var flex_material_ratio: float = _calculate_profile_material_support_ratio(segments, material_lookup, &"flex")
	var joint_component: float = 0.0
	if joint_data.get("joint_chain_valid", false):
		joint_component = clampf(float(joint_data.get("link_count", 0)) / 4.0, 0.0, 1.0)

	var bow_component: float = 0.0
	if bow_data.get("bow_valid", false):
		var upper_flex: float = float(bow_data.get("upper_limb_flex_score", 0.0))
		var lower_flex: float = float(bow_data.get("lower_limb_flex_score", 0.0))
		var string_tension: float = float(bow_data.get("string_tension_score", 0.0))
		bow_component = ((upper_flex + lower_flex) * 0.5) * string_tension

	return clampf(maxf(joint_component, bow_component) * flex_material_ratio, 0.0, 1.0)

func _calculate_launch_score(segments: Array[SegmentAtom], material_lookup: Dictionary, bow_data: Dictionary) -> float:
	if not bow_data.get("bow_valid", false):
		return 0.0
	var projectile_pass_point: Vector3 = bow_data.get("projectile_pass_point", Vector3.ZERO)
	if projectile_pass_point.is_equal_approx(Vector3.ZERO):
		return 0.0
	var launch_material_ratio: float = _calculate_profile_material_support_ratio(segments, material_lookup, &"launch")
	var string_tension: float = float(bow_data.get("string_tension_score", 0.0))
	return clampf(launch_material_ratio * string_tension, 0.0, 1.0)

func _calculate_total_segment_mass(segments: Array[SegmentAtom], material_lookup: Dictionary) -> float:
	var total_mass: float = 0.0
	for segment: SegmentAtom in segments:
		total_mass += _calculate_segment_mass(segment, material_lookup)
	return total_mass

func _calculate_segment_mass(segment: SegmentAtom, material_lookup: Dictionary) -> float:
	if segment == null:
		return 0.0
	var segment_mass: float = 0.0
	for cell: CellAtom in segment.member_cells:
		segment_mass += _get_cell_mass(cell, material_lookup)
	return segment_mass

func _calculate_material_support_ratio(segment: SegmentAtom, material_lookup: Dictionary, support_type: StringName) -> float:
	if segment == null or segment.member_cells.is_empty():
		return 0.0

	var supporting_cell_count: int = 0
	for cell: CellAtom in segment.member_cells:
		if _supports_profile_score_type(cell, material_lookup, support_type):
			supporting_cell_count += 1

	return float(supporting_cell_count) / float(segment.member_cells.size())

func _calculate_profile_material_support_ratio(segments: Array[SegmentAtom], material_lookup: Dictionary, support_type: StringName) -> float:
	var total_cells: int = 0
	var supporting_cells: int = 0
	for segment: SegmentAtom in segments:
		if segment == null:
			continue
		for cell: CellAtom in segment.member_cells:
			if cell == null:
				continue
			total_cells += 1
			if _supports_profile_score_type(cell, material_lookup, support_type):
				supporting_cells += 1
	if total_cells == 0:
		return 0.0
	return float(supporting_cells) / float(total_cells)

func _supports_profile_score_type(cell: CellAtom, material_lookup: Dictionary, support_type: StringName) -> bool:
	var base_material: BaseMaterialDef = material_runtime_resolver.resolve_base_material_for_cell(cell, material_lookup)
	if base_material == null:
		return false
	match support_type:
		&"edge":
			return base_material.can_be_beveled_edge
		&"blunt":
			return base_material.can_be_blunt_surface
		&"pierce":
			return material_runtime_resolver.has_positive_capability_bias_for_cell(cell, material_lookup, &"cap_pierce")
		&"guard":
			return base_material.can_be_guard_surface or base_material.can_be_plate_surface
		&"flex":
			return (
				material_runtime_resolver.has_positive_capability_bias_for_cell(cell, material_lookup, &"cap_flex")
				or base_material.can_be_joint_support
				or base_material.can_be_joint_membrane
				or base_material.can_be_bow_limb
			)
		&"launch":
			return (
				material_runtime_resolver.has_positive_capability_bias_for_cell(cell, material_lookup, &"cap_launch")
				or base_material.can_be_projectile_support
				or base_material.can_be_bow_string
			)
		_:
			return false
