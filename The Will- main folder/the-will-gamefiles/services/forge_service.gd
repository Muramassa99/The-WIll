extends RefCounted
class_name ForgeService

const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")
const CraftedItemCanonicalSolidResolverScript = preload("res://core/resolvers/crafted_item_canonical_solid_resolver.gd")
const CraftedItemCanonicalGeometryResolverScript = preload("res://core/resolvers/crafted_item_canonical_geometry_resolver.gd")
const ForgeStage2ServiceScript = preload("res://services/forge_stage2_service.gd")
const MaterialRuntimeResolverScript = preload("res://core/resolvers/material_runtime_resolver.gd")

var forge_rules: ForgeRulesDef = DEFAULT_FORGE_RULES_RESOURCE
var tier_resolver: TierResolver
var process_resolver: ProcessResolver
var segment_resolver: SegmentResolver
var anchor_resolver: AnchorResolver
var joint_resolver: JointResolver
var bow_resolver: BowResolver
var profile_resolver: ProfileResolver
var capability_resolver: CapabilityResolver
var material_runtime_resolver
var canonical_solid_resolver
var canonical_geometry_resolver
var stage2_service

func _init(rules: ForgeRulesDef = null) -> void:
	tier_resolver = TierResolver.new()
	process_resolver = ProcessResolver.new()
	capability_resolver = CapabilityResolver.new()
	material_runtime_resolver = MaterialRuntimeResolverScript.new()
	canonical_solid_resolver = CraftedItemCanonicalSolidResolverScript.new()
	canonical_geometry_resolver = CraftedItemCanonicalGeometryResolverScript.new()
	set_forge_rules(rules)
	stage2_service = ForgeStage2ServiceScript.new(forge_rules)

func set_forge_rules(rules: ForgeRulesDef) -> void:
	forge_rules = rules if rules != null else DEFAULT_FORGE_RULES_RESOURCE
	segment_resolver = SegmentResolver.new(forge_rules)
	anchor_resolver = AnchorResolver.new(forge_rules)
	joint_resolver = JointResolver.new(forge_rules)
	bow_resolver = BowResolver.new(forge_rules)
	profile_resolver = ProfileResolver.new(forge_rules)
	if stage2_service != null and stage2_service.has_method("set_forge_rules"):
		stage2_service.call("set_forge_rules", forge_rules)

func bake_wip(
		wip: CraftedItemWIP,
		material_lookup: Dictionary = {},
		shape_data: Dictionary = {},
		joint_data: Dictionary = {},
		bow_data: Dictionary = {}
	) -> BakedProfile:
	if wip == null:
		return null

	var authored_cells: Array[CellAtom] = _collect_authored_wip_cells(wip)
	var cells: Array[CellAtom] = _collect_wip_cells(wip)
	var segments: Array[SegmentAtom] = build_segments(cells, material_lookup)
	segments = classify_joint_segments(segments, material_lookup)
	var anchors: Array[AnchorAtom] = build_anchors(segments, material_lookup)
	var resolved_joint_data: Dictionary = joint_data if not joint_data.is_empty() else build_joint_data(segments, material_lookup)
	var resolved_bow_data: Dictionary = bow_data if not bow_data.is_empty() else build_bow_data(
		segments,
		material_lookup,
		wip.forge_intent,
		wip.equipment_context,
		authored_cells,
		anchors
	)
	var profile: BakedProfile = bake_profile(
		cells,
		segments,
		anchors,
		material_lookup,
		shape_data,
		resolved_joint_data,
		resolved_bow_data,
		wip.forge_intent,
		wip.equipment_context
	)
	profile.profile_id = _build_profile_id(wip)
	profile.material_variant_mix = _collect_material_variant_mix(cells)
	profile.resolved_material_stat_lines = _collect_aggregated_material_lines(cells, material_lookup, &"material_stats")
	profile.resolved_capability_bias_lines = _collect_aggregated_material_lines(cells, material_lookup, &"capability_bias")
	profile.resolved_skill_family_bias_lines = _collect_aggregated_material_lines(cells, material_lookup, &"skill_family_bias")
	profile.resolved_elemental_affinity_lines = _collect_aggregated_material_lines(cells, material_lookup, &"elemental_affinity")
	profile.resolved_equipment_context_bias_lines = _collect_aggregated_material_lines(cells, material_lookup, &"equipment_context_bias")
	profile.capability_scores = derive_capability_scores(profile, profile.resolved_capability_bias_lines)
	wip.latest_baked_profile_snapshot = profile.duplicate(true) as BakedProfile
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
	test_print.canonical_solid = canonical_solid_resolver.call("resolve_from_cells", test_print.display_cells)
	var stage1_canonical_geometry = canonical_geometry_resolver.call("resolve_from_solid", test_print.canonical_solid)
	var stage2_item_state = (
		wip.stage2_item_state.duplicate(true)
		if wip != null and wip.stage2_item_state != null
		else null
	)
	if (
		stage2_item_state == null or not stage2_item_state.has_current_shell()
	) and stage2_service != null:
		stage2_item_state = stage2_service.build_stage2_item_state_from_stage1(
			wip,
			test_print.canonical_solid,
			stage1_canonical_geometry,
			profile,
			material_lookup
		)
		if wip != null and stage2_item_state != null:
			wip.stage2_item_state = stage2_item_state.duplicate(true)
	var stage2_canonical_geometry = null
	if stage2_item_state != null and stage2_item_state.has_current_shell():
		stage2_canonical_geometry = stage2_item_state.build_current_canonical_geometry(test_print.canonical_solid)
	test_print.stage2_item_state = stage2_item_state
	test_print.canonical_geometry = (
		stage2_canonical_geometry
		if stage2_canonical_geometry != null and not stage2_canonical_geometry.is_empty()
		else stage1_canonical_geometry
	)
	test_print.visual_mesh_source = (
		&"editable_mesh"
		if (
			stage2_item_state != null
			and stage2_item_state.has_current_editable_mesh()
			and bool(stage2_item_state.get("editable_mesh_visual_authority"))
		)
		else &"canonical_geometry"
	)
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

func build_bow_data(
	segments: Array[SegmentAtom],
	material_lookup: Dictionary = {},
	forge_intent: StringName = &"",
	equipment_context: StringName = &"",
	authored_cells: Array[CellAtom] = [],
	anchors: Array[AnchorAtom] = []
) -> Dictionary:
	var resolved_anchors: Array[AnchorAtom] = anchors
	if resolved_anchors.is_empty():
		resolved_anchors = build_anchors(segments, material_lookup)
	var primary_grip_valid: bool = false
	for anchor: AnchorAtom in resolved_anchors:
		if anchor == null:
			continue
		if anchor.anchor_type == "primary_grip":
			primary_grip_valid = true
			break
	return bow_resolver.validate_bow_structure(
		segments,
		material_lookup,
		forge_intent,
		equipment_context,
		authored_cells,
		primary_grip_valid
	)

func bake_profile(
		cells: Array[CellAtom],
		segments: Array[SegmentAtom],
		anchors: Array[AnchorAtom],
		material_lookup: Dictionary = {},
		shape_data: Dictionary = {},
		joint_data: Dictionary = {},
		bow_data: Dictionary = {},
		forge_intent: StringName = &"",
		equipment_context: StringName = &""
	) -> BakedProfile:
	return profile_resolver.bake_profile(
		cells,
		segments,
		anchors,
		material_lookup,
		shape_data,
		joint_data,
		bow_data,
		forge_intent,
		equipment_context
	)

func derive_capability_scores(
		profile: BakedProfile,
		material_bias_lines: Array[StatLine] = [],
		context_bias_lines: Array[StatLine] = []
	) -> Dictionary[StringName, float]:
	return capability_resolver.derive_capability_scores(profile, material_bias_lines, context_bias_lines)

func _collect_wip_cells(wip: CraftedItemWIP) -> Array[CellAtom]:
	return CraftedItemWIP.collect_bake_cells(wip)

func _collect_authored_wip_cells(wip: CraftedItemWIP) -> Array[CellAtom]:
	return CraftedItemWIP.collect_cells(wip, true)

func _build_test_print_id(wip: CraftedItemWIP) -> StringName:
	if wip == null or wip.wip_id == StringName():
		return &"test_print_runtime"
	return StringName("test_print_%s" % String(wip.wip_id))

func _build_profile_id(wip: CraftedItemWIP) -> StringName:
	if wip == null or wip.wip_id == StringName():
		return &"profile_runtime"
	return StringName("profile_%s" % String(wip.wip_id))

func _collect_aggregated_material_lines(
		cells: Array[CellAtom],
		material_lookup: Dictionary,
		line_kind: StringName
	) -> Array[StatLine]:
	var line_lookup: Dictionary = {}
	for cell: CellAtom in cells:
		_merge_stat_lines(line_lookup, _resolve_material_lines_for_cell(cell, material_lookup, line_kind))
	return _build_sorted_stat_line_array(line_lookup)

func _resolve_material_lines_for_cell(
		cell: CellAtom,
		material_lookup: Dictionary,
		line_kind: StringName
	) -> Array[StatLine]:
	match line_kind:
		&"material_stats":
			return material_runtime_resolver.resolve_material_stat_lines_for_cell(cell, material_lookup)
		&"capability_bias":
			return material_runtime_resolver.resolve_capability_bias_lines_for_cell(cell, material_lookup)
		&"skill_family_bias":
			return material_runtime_resolver.resolve_skill_family_bias_lines_for_cell(cell, material_lookup)
		&"elemental_affinity":
			return material_runtime_resolver.resolve_elemental_affinity_lines_for_cell(cell, material_lookup)
		&"equipment_context_bias":
			return material_runtime_resolver.resolve_equipment_context_bias_lines_for_cell(cell, material_lookup)
		_:
			return []

func _merge_stat_lines(line_lookup: Dictionary, stat_lines: Array[StatLine]) -> void:
	for stat_line: StatLine in stat_lines:
		if stat_line == null or not stat_line.is_valid():
			continue
		var line_key: String = _build_stat_line_key(stat_line)
		var existing_line: StatLine = line_lookup.get(line_key) as StatLine
		if existing_line == null:
			line_lookup[line_key] = stat_line.copy_scaled(1.0)
			continue
		if stat_line.is_numeric():
			existing_line.value += stat_line.value
			continue
		if stat_line.is_flag():
			existing_line.value = maxf(existing_line.value, stat_line.value)
			continue
		if stat_line.is_enum() and existing_line.enum_value == StringName():
			existing_line.enum_value = stat_line.enum_value

func _build_sorted_stat_line_array(line_lookup: Dictionary) -> Array[StatLine]:
	var sorted_keys: Array = line_lookup.keys()
	sorted_keys.sort()
	var sorted_lines: Array[StatLine] = []
	for line_key in sorted_keys:
		var stat_line: StatLine = line_lookup.get(line_key) as StatLine
		if stat_line == null:
			continue
		sorted_lines.append(stat_line)
	return sorted_lines

func _build_stat_line_key(stat_line: StatLine) -> String:
	return "%s|%d|%s" % [String(stat_line.stat_id), int(stat_line.value_kind), String(stat_line.enum_value)]

func _collect_material_variant_mix(cells: Array[CellAtom]) -> Dictionary:
	var material_variant_mix: Dictionary = {}
	for cell: CellAtom in cells:
		if cell == null or cell.material_variant_id == StringName():
			continue
		material_variant_mix[cell.material_variant_id] = int(material_variant_mix.get(cell.material_variant_id, 0)) + 1
	return material_variant_mix
