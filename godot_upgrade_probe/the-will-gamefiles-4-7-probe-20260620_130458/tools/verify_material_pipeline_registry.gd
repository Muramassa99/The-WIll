extends SceneTree

const MaterialPipelineServiceScript = preload("res://services/material_pipeline_service.gd")

const MaterialCatalogResource: Resource = preload("res://core/defs/forge/forge_material_catalog_default.tres")
const RawDropRegistryResource: Resource = preload("res://core/defs/materials/raw_drops/raw_drop_registry_default.tres")
const ProcessRuleRegistryResource: Resource = preload("res://core/defs/materials/process_rules/process_rule_registry_default.tres")
const TierRegistryResource: Resource = preload("res://core/defs/materials/tiers/tier_registry_default.tres")

func _init() -> void:
	var material_pipeline_service = MaterialPipelineServiceScript.new()
	var raw_drop_lookup: Dictionary = material_pipeline_service.build_raw_drop_lookup(RawDropRegistryResource)
	var raw_drop_by_material_lookup: Dictionary = material_pipeline_service.build_raw_drop_lookup_by_material(RawDropRegistryResource)
	var process_rule_lookup: Dictionary = material_pipeline_service.build_process_rule_lookup(ProcessRuleRegistryResource)
	var process_rule_by_drop_lookup: Dictionary = material_pipeline_service.build_process_rule_lookup_by_drop(ProcessRuleRegistryResource)

	var material_count: int = MaterialCatalogResource.entries.size() if MaterialCatalogResource != null else 0
	var valid_pipeline_count: int = 0
	var lines: PackedStringArray = []
	lines.append("material_catalog_count=%d" % material_count)
	lines.append("raw_drop_registry_count=%d" % raw_drop_lookup.size())
	lines.append("raw_drop_by_material_count=%d" % raw_drop_by_material_lookup.size())
	lines.append("process_rule_registry_count=%d" % process_rule_lookup.size())
	lines.append("process_rule_by_drop_count=%d" % process_rule_by_drop_lookup.size())

	if MaterialCatalogResource != null:
		for catalog_entry: Resource in MaterialCatalogResource.entries:
			if catalog_entry == null:
				continue
			var base_material: BaseMaterialDef = catalog_entry.material_def as BaseMaterialDef
			if base_material == null:
				continue
			var pipeline: Dictionary = material_pipeline_service.resolve_pipeline_for_material(
				base_material,
				null,
				RawDropRegistryResource,
				ProcessRuleRegistryResource,
				TierRegistryResource
			)
			var raw_drop: RawDropDef = pipeline.get("raw_drop") as RawDropDef
			var process_rule: ProcessRuleDef = pipeline.get("process_rule") as ProcessRuleDef
			var tier_def: TierDef = pipeline.get("tier") as TierDef
			var material_variant: MaterialVariantDef = pipeline.get("material_variant") as MaterialVariantDef
			var material_stack: ForgeMaterialStack = pipeline.get("material_stack") as ForgeMaterialStack
			var output_matches_variant: bool = bool(pipeline.get("output_matches_variant", false))
			var material_id_text: String = String(base_material.base_material_id)
			lines.append("%s_raw_drop_found=%s" % [material_id_text, str(raw_drop != null)])
			lines.append("%s_process_rule_found=%s" % [material_id_text, str(process_rule != null)])
			lines.append("%s_tier_id=%s" % [material_id_text, String(tier_def.tier_id if tier_def != null else StringName())])
			lines.append("%s_raw_drop_id=%s" % [material_id_text, String(raw_drop.drop_id if raw_drop != null else StringName())])
			lines.append("%s_process_input_drop_id=%s" % [material_id_text, String(process_rule.input_drop_id if process_rule != null else StringName())])
			lines.append("%s_variant_id=%s" % [material_id_text, String(material_variant.variant_id if material_variant != null else StringName())])
			lines.append("%s_output_matches_variant=%s" % [material_id_text, str(output_matches_variant)])
			lines.append("%s_stack_quantity=%d" % [material_id_text, material_stack.quantity if material_stack != null else 0])
			if raw_drop != null and process_rule != null and material_stack != null and output_matches_variant:
				valid_pipeline_count += 1

	lines.append("valid_pipeline_count=%d" % valid_pipeline_count)
	lines.append("all_catalog_materials_have_valid_pipeline=%s" % str(valid_pipeline_count == material_count))

	var output: String = "\n".join(lines)
	var file: FileAccess = FileAccess.open("c:/WORKSPACE/material_pipeline_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string(output)
		file.close()
	quit()
