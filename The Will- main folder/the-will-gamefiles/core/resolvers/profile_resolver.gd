extends RefCounted
class_name ProfileResolver

const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")
const MaterialRuntimeResolverScript = preload("res://core/resolvers/material_runtime_resolver.gd")
const ProfilePrimaryGripResolverScript = preload("res://core/resolvers/profile_primary_grip_resolver.gd")
const ProfileCapabilityScoreResolverScript = preload("res://core/resolvers/profile_capability_score_resolver.gd")

var forge_rules: ForgeRulesDef = DEFAULT_FORGE_RULES_RESOURCE
var shape_classifier_resolver: ShapeClassifierResolver = ShapeClassifierResolver.new()
var material_runtime_resolver = MaterialRuntimeResolverScript.new()
var primary_grip_resolver
var capability_score_resolver

func _init(rules: ForgeRulesDef = null) -> void:
	forge_rules = rules if rules != null else DEFAULT_FORGE_RULES_RESOURCE
	primary_grip_resolver = ProfilePrimaryGripResolverScript.new(forge_rules)
	capability_score_resolver = ProfileCapabilityScoreResolverScript.new(
		shape_classifier_resolver,
		material_runtime_resolver
	)

func bake_profile(
		cells: Array[CellAtom],
		segments: Array[SegmentAtom],
		anchors: Array[AnchorAtom],
		material_lookup: Dictionary = {},
		_shape_data: Dictionary = {},
		joint_data: Dictionary = {},
		bow_data: Dictionary = {},
		forge_intent: StringName = &"",
		equipment_context: StringName = &""
	) -> BakedProfile:
	var profile: BakedProfile = BakedProfile.new()
	profile.total_mass = _calculate_total_mass(cells, material_lookup)
	profile.center_of_mass = _calculate_center_of_mass(cells, material_lookup, profile.total_mass)
	if not _is_connectivity_valid(cells, segments):
		profile.validation_error = "disconnected_islands"

	primary_grip_resolver.apply_primary_grip_profile(
		profile,
		cells,
		anchors,
		profile.center_of_mass,
		forge_intent,
		equipment_context
	)

	capability_score_resolver.apply_profile_capability_scores(
		profile,
		segments,
		material_lookup,
		joint_data,
		bow_data
	)
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
