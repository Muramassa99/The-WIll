extends RefCounted
class_name ForgeService

const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")

var forge_rules: ForgeRulesDef = DEFAULT_FORGE_RULES_RESOURCE
var tier_resolver: TierResolver
var process_resolver: ProcessResolver
var segment_resolver: SegmentResolver
var anchor_resolver: AnchorResolver
var joint_resolver: JointResolver
var bow_resolver: BowResolver
var profile_resolver: ProfileResolver
var capability_resolver: CapabilityResolver

func _init(rules: ForgeRulesDef = null) -> void:
	tier_resolver = TierResolver.new()
	process_resolver = ProcessResolver.new()
	profile_resolver = ProfileResolver.new()
	capability_resolver = CapabilityResolver.new()
	set_forge_rules(rules)

func set_forge_rules(rules: ForgeRulesDef) -> void:
	forge_rules = rules if rules != null else DEFAULT_FORGE_RULES_RESOURCE
	segment_resolver = SegmentResolver.new(forge_rules)
	anchor_resolver = AnchorResolver.new(forge_rules)
	joint_resolver = JointResolver.new(forge_rules)
	bow_resolver = BowResolver.new(forge_rules)

func bake_wip(
		wip: CraftedItemWIP,
		material_lookup: Dictionary = {},
		shape_data: Dictionary = {},
		joint_data: Dictionary = {},
		bow_data: Dictionary = {}
	) -> BakedProfile:
	if wip == null:
		return null

	var cells: Array[CellAtom] = _collect_wip_cells(wip)
	var segments: Array[SegmentAtom] = build_segments(cells, material_lookup)
	segments = classify_joint_segments(segments, material_lookup)
	var anchors: Array[AnchorAtom] = build_anchors(segments, material_lookup)
	var resolved_joint_data: Dictionary = joint_data if not joint_data.is_empty() else build_joint_data(segments, material_lookup)
	var resolved_bow_data: Dictionary = bow_data if not bow_data.is_empty() else build_bow_data(
		segments,
		material_lookup,
		wip.forge_intent,
		wip.equipment_context
	)
	var profile: BakedProfile = bake_profile(cells, segments, anchors, material_lookup, shape_data, resolved_joint_data, resolved_bow_data)
	profile.profile_id = _build_profile_id(wip)
	var material_bias_lines: Array[StatLine] = _collect_material_capability_bias_lines(cells, material_lookup)
	profile.capability_scores = derive_capability_scores(profile, material_bias_lines)
	wip.latest_baked_profile_snapshot = profile.duplicate(true) as BakedProfile
	debug_print_profile(profile)
	return profile

func build_test_print_from_wip(
		wip: CraftedItemWIP,
		material_lookup: Dictionary = {},
		shape_data: Dictionary = {},
		joint_data: Dictionary = {},
		bow_data: Dictionary = {}
	) -> TestPrintInstance:
	var profile: BakedProfile = bake_wip(wip, material_lookup, shape_data, joint_data, bow_data)
	if profile == null:
		return null

	var test_print: TestPrintInstance = TestPrintInstance.new()
	test_print.test_id = _build_test_print_id(wip)
	test_print.source_wip_id = wip.wip_id
	test_print.baked_profile = profile
	test_print.display_cells = _collect_wip_cells(wip)
	return test_print

func build_material_variant(base_material: BaseMaterialDef, tier: TierDef) -> MaterialVariantDef:
	return tier_resolver.build_variant(base_material, tier)

func build_material_stack(process_rule: ProcessRuleDef, material_variant: MaterialVariantDef) -> ForgeMaterialStack:
	return process_resolver.build_stack(process_rule, material_variant)

func build_segments(cells: Array[CellAtom], material_lookup: Dictionary = {}) -> Array[SegmentAtom]:
	return segment_resolver.resolve_segments(cells, material_lookup)

func build_anchors(segments: Array[SegmentAtom], material_lookup: Dictionary = {}) -> Array[AnchorAtom]:
	return anchor_resolver.resolve_anchors(segments, material_lookup)

func classify_joint_segments(segments: Array[SegmentAtom], material_lookup: Dictionary = {}) -> Array[SegmentAtom]:
	return joint_resolver.classify_joint_segments(segments, material_lookup)

func build_joint_data(segments: Array[SegmentAtom], material_lookup: Dictionary = {}) -> Dictionary:
	for segment: SegmentAtom in segments:
		if segment == null:
			continue
		if not joint_resolver.validate_joint_chain(segment, material_lookup):
			continue
		return joint_resolver.resolve_joint_properties(segment)
	return {
		"joint_chain_valid": false,
		"joint_type": &"none",
		"joint_axis": Vector3.ZERO,
		"motion_plane": &"",
		"link_count": 0,
		"hinge_count": 0,
		"angle_limit_min": 0.0,
		"angle_limit_max": 0.0,
		"supports_axial_spin": false,
		"supports_planar_hinge": false,
		"self_collision_mode": &"none",
		"validation_error": &"no_valid_joint_chain",
	}

func build_bow_data(segments: Array[SegmentAtom], material_lookup: Dictionary = {}, forge_intent: StringName = &"", equipment_context: StringName = &"") -> Dictionary:
	return bow_resolver.validate_bow_structure(segments, material_lookup, forge_intent, equipment_context)

func bake_profile(
		cells: Array[CellAtom],
		segments: Array[SegmentAtom],
		anchors: Array[AnchorAtom],
		material_lookup: Dictionary = {},
		shape_data: Dictionary = {},
		joint_data: Dictionary = {},
		bow_data: Dictionary = {}
	) -> BakedProfile:
	return profile_resolver.bake_profile(cells, segments, anchors, material_lookup, shape_data, joint_data, bow_data)

func derive_capability_scores(
		profile: BakedProfile,
		material_bias_lines: Array[StatLine] = [],
		context_bias_lines: Array[StatLine] = []
	) -> Dictionary[StringName, float]:
	return capability_resolver.derive_capability_scores(profile, material_bias_lines, context_bias_lines)

func debug_print_profile(profile: BakedProfile) -> void:
	if profile == null:
		print("ForgeService: no baked profile available")
		return

	print("ForgeService baked profile")
	print("  total_mass=", profile.total_mass)
	print("  center_of_mass=", profile.center_of_mass)
	print("  reach=", profile.reach)
	print("  front_heavy_score=", profile.front_heavy_score)
	print("  balance_score=", profile.balance_score)
	print("  edge_score=", profile.edge_score)
	print("  blunt_score=", profile.blunt_score)
	print("  pierce_score=", profile.pierce_score)
	print("  guard_score=", profile.guard_score)
	print("  flex_score=", profile.flex_score)
	print("  launch_score=", profile.launch_score)
	print("  capability_scores=", profile.capability_scores)

func _collect_wip_cells(wip: CraftedItemWIP) -> Array[CellAtom]:
	var cells: Array[CellAtom] = []
	for layer in wip.layers:
		if layer == null:
			continue
		for cell in layer.cells:
			if cell == null:
				continue
			cells.append(cell)
	return cells

func _build_test_print_id(wip: CraftedItemWIP) -> StringName:
	if wip == null or wip.wip_id == StringName():
		return &"test_print_runtime"
	return StringName("test_print_%s" % String(wip.wip_id))

func _build_profile_id(wip: CraftedItemWIP) -> StringName:
	if wip == null or wip.wip_id == StringName():
		return &"profile_runtime"
	return StringName("profile_%s" % String(wip.wip_id))

func _collect_material_capability_bias_lines(cells: Array[CellAtom], material_lookup: Dictionary) -> Array[StatLine]:
	var material_bias_lines: Array[StatLine] = []
	for cell: CellAtom in cells:
		var base_material: BaseMaterialDef = _resolve_base_material_for_cell(cell, material_lookup)
		if base_material == null:
			continue
		for bias_line: StatLine in base_material.capability_bias_lines:
			if bias_line == null:
				continue
			material_bias_lines.append(bias_line)
	return material_bias_lines

func _resolve_base_material_for_cell(cell: CellAtom, material_lookup: Dictionary) -> BaseMaterialDef:
	if cell == null:
		return null

	var material_entry: Variant = material_lookup.get(cell.material_variant_id)
	if material_entry is BaseMaterialDef:
		return material_entry as BaseMaterialDef
	if material_entry is MaterialVariantDef:
		var material_variant: MaterialVariantDef = material_entry as MaterialVariantDef
		var base_material_entry: Variant = material_lookup.get(material_variant.base_material_id)
		if base_material_entry is BaseMaterialDef:
			return base_material_entry as BaseMaterialDef
	return null
