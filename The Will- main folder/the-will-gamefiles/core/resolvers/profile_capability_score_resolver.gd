extends RefCounted
class_name ProfileCapabilityScoreResolver

var shape_classifier_resolver
var material_runtime_resolver

func _init(resolved_shape_classifier_resolver, resolved_material_runtime_resolver) -> void:
	shape_classifier_resolver = resolved_shape_classifier_resolver
	material_runtime_resolver = resolved_material_runtime_resolver

func apply_profile_capability_scores(
		profile: BakedProfile,
		segments: Array[SegmentAtom],
		material_lookup: Dictionary,
		joint_data: Dictionary,
		bow_data: Dictionary
	) -> void:
	if profile == null:
		return
	profile.edge_score = _calculate_edge_score(segments, material_lookup)
	profile.blunt_score = _calculate_blunt_score(segments, material_lookup)
	profile.pierce_score = _calculate_pierce_score(segments, material_lookup)
	profile.guard_score = _calculate_guard_score(segments, material_lookup)
	profile.flex_score = _calculate_flex_score(segments, material_lookup, joint_data, bow_data)
	profile.launch_score = _calculate_launch_score(segments, material_lookup, bow_data)

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

func _calculate_launch_score(
		segments: Array[SegmentAtom],
		material_lookup: Dictionary,
		bow_data: Dictionary
	) -> float:
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

func _calculate_material_support_ratio(
		segment: SegmentAtom,
		material_lookup: Dictionary,
		support_type: StringName
	) -> float:
	if segment == null or segment.member_cells.is_empty():
		return 0.0

	var supporting_cell_count: int = 0
	for cell: CellAtom in segment.member_cells:
		if _supports_profile_score_type(cell, material_lookup, support_type):
			supporting_cell_count += 1

	return float(supporting_cell_count) / float(segment.member_cells.size())

func _calculate_profile_material_support_ratio(
		segments: Array[SegmentAtom],
		material_lookup: Dictionary,
		support_type: StringName
	) -> float:
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

func _supports_profile_score_type(
		cell: CellAtom,
		material_lookup: Dictionary,
		support_type: StringName
	) -> bool:
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

func _get_cell_mass(cell: CellAtom, material_lookup: Dictionary) -> float:
	return material_runtime_resolver.resolve_density_per_cell(cell, material_lookup)
