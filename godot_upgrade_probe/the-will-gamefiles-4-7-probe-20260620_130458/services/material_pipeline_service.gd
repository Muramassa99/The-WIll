extends RefCounted
class_name MaterialPipelineService

const ForgeServiceScript = preload("res://services/forge_service.gd")

const DEFAULT_GRAY_TIER_RESOURCE: TierDef = preload("res://core/defs/materials/tiers/tier_gray.tres")
const DEFAULT_TIER_REGISTRY_RESOURCE: Resource = preload("res://core/defs/materials/tiers/tier_registry_default.tres")
const DEFAULT_RAW_DROP_REGISTRY_RESOURCE: Resource = preload("res://core/defs/materials/raw_drops/raw_drop_registry_default.tres")
const DEFAULT_PROCESS_RULE_REGISTRY_RESOURCE: Resource = preload("res://core/defs/materials/process_rules/process_rule_registry_default.tres")
const DEFAULT_FORGE_MATERIAL_CATALOG_RESOURCE: Resource = preload("res://core/defs/forge/forge_material_catalog_default.tres")

var forge_service: ForgeService = ForgeServiceScript.new()

func build_raw_drop_lookup(registry_def: Resource = DEFAULT_RAW_DROP_REGISTRY_RESOURCE) -> Dictionary:
	var lookup: Dictionary = {}
	for raw_drop: RawDropDef in _collect_raw_drop_defs(registry_def):
		if raw_drop == null or raw_drop.drop_id == StringName():
			continue
		lookup[raw_drop.drop_id] = raw_drop
	return lookup

func build_raw_drop_lookup_by_material(registry_def: Resource = DEFAULT_RAW_DROP_REGISTRY_RESOURCE) -> Dictionary:
	var lookup: Dictionary = {}
	for raw_drop: RawDropDef in _collect_raw_drop_defs(registry_def):
		if raw_drop == null or raw_drop.base_material_id == StringName():
			continue
		lookup[raw_drop.base_material_id] = raw_drop
	return lookup

func build_process_rule_lookup(registry_def: Resource = DEFAULT_PROCESS_RULE_REGISTRY_RESOURCE) -> Dictionary:
	var lookup: Dictionary = {}
	for process_rule: ProcessRuleDef in _collect_process_rule_defs(registry_def):
		if process_rule == null or process_rule.rule_id == StringName():
			continue
		lookup[process_rule.rule_id] = process_rule
	return lookup

func build_process_rule_lookup_by_drop(registry_def: Resource = DEFAULT_PROCESS_RULE_REGISTRY_RESOURCE) -> Dictionary:
	var lookup: Dictionary = {}
	for process_rule: ProcessRuleDef in _collect_process_rule_defs(registry_def):
		if process_rule == null or process_rule.input_drop_id == StringName():
			continue
		lookup[process_rule.input_drop_id] = process_rule
	return lookup

func find_raw_drop_for_material(base_material_id: StringName, registry_def: Resource = DEFAULT_RAW_DROP_REGISTRY_RESOURCE) -> RawDropDef:
	return build_raw_drop_lookup_by_material(registry_def).get(base_material_id) as RawDropDef

func find_process_rule_for_drop(drop_id: StringName, registry_def: Resource = DEFAULT_PROCESS_RULE_REGISTRY_RESOURCE) -> ProcessRuleDef:
	return build_process_rule_lookup_by_drop(registry_def).get(drop_id) as ProcessRuleDef

func build_base_material_lookup(catalog_def: Resource = DEFAULT_FORGE_MATERIAL_CATALOG_RESOURCE) -> Dictionary:
	var lookup: Dictionary = {}
	if catalog_def == null or catalog_def.is_empty():
		return lookup
	for entry: Resource in catalog_def.entries:
		if entry == null or not entry.has_method("get"):
			continue
		var base_material: BaseMaterialDef = entry.get("material_def") as BaseMaterialDef
		if base_material == null or base_material.base_material_id == StringName():
			continue
		lookup[base_material.base_material_id] = base_material
	return lookup

func find_base_material_by_id(
		base_material_id: StringName,
		catalog_def: Resource = DEFAULT_FORGE_MATERIAL_CATALOG_RESOURCE
	) -> BaseMaterialDef:
	return build_base_material_lookup(catalog_def).get(base_material_id) as BaseMaterialDef

func build_tier_lookup(registry_def: Resource = DEFAULT_TIER_REGISTRY_RESOURCE) -> Dictionary:
	var lookup: Dictionary = {}
	for tier_def: TierDef in _collect_tier_defs(registry_def):
		if tier_def == null or tier_def.tier_id == StringName():
			continue
		lookup[tier_def.tier_id] = tier_def
	return lookup

func find_tier_by_id(tier_id: StringName, registry_def: Resource = DEFAULT_TIER_REGISTRY_RESOURCE) -> TierDef:
	return build_tier_lookup(registry_def).get(tier_id) as TierDef

func resolve_pipeline_for_material(
		base_material: BaseMaterialDef,
		tier: TierDef = null,
		raw_drop_registry_def: Resource = DEFAULT_RAW_DROP_REGISTRY_RESOURCE,
		process_rule_registry_def: Resource = DEFAULT_PROCESS_RULE_REGISTRY_RESOURCE,
		tier_registry_def: Resource = DEFAULT_TIER_REGISTRY_RESOURCE
	) -> Dictionary:
	var raw_drop: RawDropDef = null
	var process_rule: ProcessRuleDef = null
	var resolved_tier: TierDef = tier
	var material_variant: MaterialVariantDef = null
	var material_stack: ForgeMaterialStack = null

	if base_material != null:
		raw_drop = find_raw_drop_for_material(base_material.base_material_id, raw_drop_registry_def)
	if raw_drop != null:
		process_rule = find_process_rule_for_drop(raw_drop.drop_id, process_rule_registry_def)
	if resolved_tier == null and raw_drop != null:
		resolved_tier = find_tier_by_id(raw_drop.default_tier_id, tier_registry_def)
	if resolved_tier == null:
		resolved_tier = DEFAULT_GRAY_TIER_RESOURCE
	if base_material != null and resolved_tier != null:
		material_variant = forge_service.build_material_variant(base_material, resolved_tier)

	var output_matches_variant: bool = (
		process_rule != null
		and material_variant != null
		and process_rule.output_material_variant_id == material_variant.variant_id
	)
	if output_matches_variant:
		material_stack = forge_service.build_material_stack(process_rule, material_variant)

	return {
		"base_material": base_material,
		"tier": resolved_tier,
		"raw_drop": raw_drop,
		"process_rule": process_rule,
		"material_variant": material_variant,
		"material_stack": material_stack,
		"output_matches_variant": output_matches_variant,
	}

func _collect_raw_drop_defs(registry_def: Resource) -> Array[RawDropDef]:
	var raw_drop_defs: Array[RawDropDef] = []
	if registry_def == null or registry_def.is_empty():
		return raw_drop_defs
	for entry: Resource in registry_def.entries:
		var raw_drop: RawDropDef = entry as RawDropDef
		if raw_drop == null:
			continue
		raw_drop_defs.append(raw_drop)
	return raw_drop_defs

func _collect_process_rule_defs(registry_def: Resource) -> Array[ProcessRuleDef]:
	var process_rule_defs: Array[ProcessRuleDef] = []
	if registry_def == null or registry_def.is_empty():
		return process_rule_defs
	for entry: Resource in registry_def.entries:
		var process_rule: ProcessRuleDef = entry as ProcessRuleDef
		if process_rule == null:
			continue
		process_rule_defs.append(process_rule)
	return process_rule_defs

func _collect_tier_defs(registry_def: Resource) -> Array[TierDef]:
	var tier_defs: Array[TierDef] = []
	if registry_def == null or registry_def.is_empty():
		return tier_defs
	for entry: Resource in registry_def.entries:
		var tier_def: TierDef = entry as TierDef
		if tier_def == null:
			continue
		tier_defs.append(tier_def)
	return tier_defs
