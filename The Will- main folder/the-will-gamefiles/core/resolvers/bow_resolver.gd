extends RefCounted
class_name BowResolver

const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")
const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const MaterialRuntimeResolverScript = preload("res://core/resolvers/material_runtime_resolver.gd")
const BowConnectedRegionResolverScript = preload("res://core/resolvers/bow_connected_region_resolver.gd")
const BowLimbValidationResolverScript = preload("res://core/resolvers/bow_limb_validation_resolver.gd")
const BowReferenceGeometryResolverScript = preload("res://core/resolvers/bow_reference_geometry_resolver.gd")

var forge_rules: ForgeRulesDef = DEFAULT_FORGE_RULES_RESOURCE
var subsegment_resolver: SegmentResolver = SegmentResolver.new(DEFAULT_FORGE_RULES_RESOURCE)
var material_runtime_resolver = MaterialRuntimeResolverScript.new()
var connected_region_resolver
var limb_validation_resolver
var reference_geometry_resolver

func _init(rules: ForgeRulesDef = null) -> void:
	forge_rules = rules if rules != null else DEFAULT_FORGE_RULES_RESOURCE
	subsegment_resolver = SegmentResolver.new(forge_rules)
	connected_region_resolver = BowConnectedRegionResolverScript.new(forge_rules)
	limb_validation_resolver = BowLimbValidationResolverScript.new(forge_rules)
	reference_geometry_resolver = BowReferenceGeometryResolverScript.new()

func validate_bow_structure(
		segments: Array[SegmentAtom],
		material_lookup: Dictionary,
		forge_intent: StringName,
		equipment_context: StringName,
		authored_cells: Array[CellAtom] = [],
		primary_grip_valid: bool = false
	) -> Dictionary:
	_clear_segment_role_hints(segments)
	var explicit_string_anchor_pair: Dictionary = CraftedItemWIPScript.resolve_first_complete_string_anchor_pair(authored_cells)
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

	var riser_segment: SegmentAtom = limb_validation_resolver.find_riser_segment(
		segments,
		Callable(reference_geometry_resolver, "calculate_segments_center"),
		Callable(reference_geometry_resolver, "get_segment_center")
	)
	var bow_string_segment: SegmentAtom = limb_validation_resolver.find_bow_string_segment(segments)
	var limb_pair: Dictionary = limb_validation_resolver.resolve_limb_pair(
		segments,
		material_lookup,
		riser_segment,
		Callable(reference_geometry_resolver, "calculate_segments_center"),
		Callable(reference_geometry_resolver, "get_segment_center")
	)
	var upper_limb_segment: SegmentAtom = limb_pair.get("upper")
	var lower_limb_segment: SegmentAtom = limb_pair.get("lower")
	if riser_segment == null or bow_string_segment == null or upper_limb_segment == null or lower_limb_segment == null:
		var connected_regions: Dictionary = connected_region_resolver.resolve_connected_bow_regions(segments, material_lookup)
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
	var reference_points: Dictionary = resolve_bow_reference_points(
		segments,
		riser_segment,
		upper_limb_segment,
		lower_limb_segment,
		explicit_string_anchor_pair
	)
	var axes: Dictionary = resolve_bow_axes(reference_points.get("bow_reference_center", Vector3.ZERO))

	var upper_limb_valid: bool = limb_validation_resolver.is_valid_limb_segment(upper_limb_segment, material_lookup)
	var lower_limb_valid: bool = limb_validation_resolver.is_valid_limb_segment(lower_limb_segment, material_lookup)
	var explicit_string_anchor_valid: bool = bool(explicit_string_anchor_pair.get("valid", false))
	var bow_string_valid: bool = explicit_string_anchor_valid or limb_validation_resolver.is_valid_bow_string(bow_string_segment, material_lookup)
	var bow_valid: bool = primary_grip_valid and riser_segment != null and upper_limb_valid and lower_limb_valid and bow_string_valid and not reference_points.get("projectile_pass_point", Vector3.ZERO).is_equal_approx(Vector3.ZERO)
	var upper_limb_flex_score: float = limb_validation_resolver.calculate_limb_flex_score(upper_limb_segment, material_lookup) if upper_limb_valid else 0.0
	var lower_limb_flex_score: float = limb_validation_resolver.calculate_limb_flex_score(lower_limb_segment, material_lookup) if lower_limb_valid else 0.0
	var string_tension_score: float = 1.0 if bow_string_valid else 0.0
	var string_pull_point_rest: Vector3 = reference_points.get("projectile_pass_point", Vector3.ZERO)
	var string_pull_point_draw_max: Vector3 = _resolve_string_pull_point_draw_max(axes, string_pull_point_rest)
	var string_rest_path: Array[Vector3] = _build_string_path(reference_points, string_pull_point_rest)
	var string_draw_path: Array[Vector3] = _build_string_path(reference_points, string_pull_point_draw_max)
	var string_anchor_span_meters: float = _measure_anchor_span(reference_points)
	var string_draw_distance_meters: float = (
		string_pull_point_rest.distance_to(string_pull_point_draw_max)
		if not string_pull_point_rest.is_equal_approx(Vector3.ZERO) and not string_pull_point_draw_max.is_equal_approx(Vector3.ZERO)
		else 0.0
	)

	return {
		"bow_valid": bow_valid,
		"primary_grip_valid": primary_grip_valid,
		"bow_reference_center": reference_points.get("bow_reference_center", Vector3.ZERO),
		"projectile_pass_point": reference_points.get("projectile_pass_point", Vector3.ZERO),
		"shoot_axis": axes.get("shoot_axis", Vector3.ZERO),
		"draw_axis": axes.get("draw_axis", Vector3.ZERO),
		"upper_string_anchor": reference_points.get("upper_string_anchor", Vector3.ZERO),
		"lower_string_anchor": reference_points.get("lower_string_anchor", Vector3.ZERO),
		"string_anchor_source": reference_points.get("string_anchor_source", &"segment_inferred"),
		"string_anchor_pair_id": reference_points.get("string_anchor_pair_id", StringName()),
		"string_pull_point_rest": string_pull_point_rest,
		"string_pull_point_draw_max": string_pull_point_draw_max,
		"string_anchor_span_meters": string_anchor_span_meters,
		"string_draw_distance_meters": string_draw_distance_meters,
		"string_rest_length_meters": _measure_string_path_length(string_rest_path),
		"string_draw_length_meters": _measure_string_path_length(string_draw_path),
		"string_rest_path": string_rest_path,
		"string_draw_path": string_draw_path,
		"upper_limb_valid": upper_limb_valid,
		"lower_limb_valid": lower_limb_valid,
		"upper_limb_flex_score": upper_limb_flex_score,
		"lower_limb_flex_score": lower_limb_flex_score,
		"string_tension_score": string_tension_score,
		"bow_asymmetry_score": limb_validation_resolver.calculate_bow_asymmetry_score(upper_limb_flex_score, lower_limb_flex_score),
		"validation_error": _resolve_validation_error(primary_grip_valid, riser_segment, upper_limb_valid, lower_limb_valid, bow_string_valid, reference_points),
	}

func resolve_bow_reference_points(
		segments: Array[SegmentAtom],
		riser_segment: SegmentAtom = null,
		upper_limb_segment: SegmentAtom = null,
		lower_limb_segment: SegmentAtom = null,
		explicit_string_anchor_pair: Dictionary = {}
	) -> Dictionary:
	return reference_geometry_resolver.resolve_bow_reference_points(
		segments,
		riser_segment,
		upper_limb_segment,
		lower_limb_segment,
		explicit_string_anchor_pair
	)

func resolve_bow_axes(_reference_center: Vector3) -> Dictionary:
	return reference_geometry_resolver.resolve_bow_axes(_reference_center)

func _is_ranged_context(forge_intent: StringName, equipment_context: StringName) -> bool:
	return forge_intent == &"intent_ranged" and equipment_context == &"ctx_weapon"

func _resolve_validation_error(
		primary_grip_valid: bool,
		riser_segment: SegmentAtom,
		upper_limb_valid: bool,
		lower_limb_valid: bool,
		bow_string_valid: bool,
		reference_points: Dictionary
	) -> StringName:
	if not primary_grip_valid:
		return &"no_primary_grip_candidate"
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

func _clear_segment_role_hints(segments: Array[SegmentAtom]) -> void:
	for segment: SegmentAtom in segments:
		if segment == null:
			continue
		segment.is_upper_limb_candidate = false
		segment.is_lower_limb_candidate = false

func _build_string_path(reference_points: Dictionary, string_pull_point: Vector3) -> Array[Vector3]:
	var upper_anchor: Vector3 = reference_points.get("upper_string_anchor", Vector3.ZERO)
	var lower_anchor: Vector3 = reference_points.get("lower_string_anchor", Vector3.ZERO)
	if upper_anchor.is_equal_approx(Vector3.ZERO) or lower_anchor.is_equal_approx(Vector3.ZERO):
		return []
	var pull_point: Vector3 = string_pull_point
	if pull_point.is_equal_approx(Vector3.ZERO):
		pull_point = (upper_anchor + lower_anchor) * 0.5
	return [
		upper_anchor,
		pull_point,
		lower_anchor,
	]

func _resolve_string_pull_point_draw_max(axes: Dictionary, string_pull_point_rest: Vector3) -> Vector3:
	if string_pull_point_rest.is_equal_approx(Vector3.ZERO):
		return Vector3.ZERO
	var draw_axis: Vector3 = axes.get("draw_axis", Vector3.ZERO)
	if draw_axis.is_equal_approx(Vector3.ZERO):
		return string_pull_point_rest
	return string_pull_point_rest + draw_axis.normalized() * forge_rules.bow_string_draw_distance_meters

func _measure_anchor_span(reference_points: Dictionary) -> float:
	var upper_anchor: Vector3 = reference_points.get("upper_string_anchor", Vector3.ZERO)
	var lower_anchor: Vector3 = reference_points.get("lower_string_anchor", Vector3.ZERO)
	if upper_anchor.is_equal_approx(Vector3.ZERO) or lower_anchor.is_equal_approx(Vector3.ZERO):
		return 0.0
	return upper_anchor.distance_to(lower_anchor)

func _measure_string_path_length(path: Array[Vector3]) -> float:
	if path.size() < 2:
		return 0.0
	var length_meters: float = 0.0
	for index in range(path.size() - 1):
		length_meters += path[index].distance_to(path[index + 1])
	return length_meters
