extends RefCounted
class_name TierResolver

func build_variant(base_material: BaseMaterialDef, tier: TierDef) -> MaterialVariantDef:
	var variant := MaterialVariantDef.new()
	variant.base_material_id = base_material.base_material_id
	variant.tier_id = tier.tier_id
	variant.variant_id = _build_variant_id(base_material, tier)
	variant.variant_stats = _scale_stat_lines(base_material.base_stat_lines, tier.stat_multiplier)
	variant.resolved_density_per_cell = base_material.density_per_cell * tier.weight_multiplier
	variant.resolved_processing_output_count = base_material.processing_output_count
	variant.resolved_value_score = tier.value_multiplier
	variant.resolved_capability_bias_lines = _scale_stat_lines(base_material.capability_bias_lines, tier.stat_multiplier)
	variant.resolved_skill_family_bias_lines = _scale_stat_lines(base_material.skill_family_bias_lines, tier.stat_multiplier)
	variant.resolved_elemental_affinity_lines = _scale_stat_lines(base_material.elemental_affinity_lines, tier.stat_multiplier)
	variant.resolved_equipment_context_bias_lines = _scale_stat_lines(base_material.equipment_context_bias_lines, tier.stat_multiplier)
	variant.resolved_animation_effect_stubs = _duplicate_animation_effect_stubs(base_material.animation_effect_stubs)
	return variant

func _scale_stat_lines(stat_lines: Array[StatLine], stat_multiplier: float) -> Array[StatLine]:
	var scaled_lines: Array[StatLine] = []
	for stat_line in stat_lines:
		if stat_line == null:
			continue
		scaled_lines.append(stat_line.copy_scaled(stat_multiplier))
	return scaled_lines

func _build_variant_id(base_material: BaseMaterialDef, tier: TierDef) -> StringName:
	if base_material == null or tier == null:
		return StringName()
	var base_material_id_text: String = String(base_material.base_material_id)
	if base_material_id_text.ends_with("_base"):
		base_material_id_text = base_material_id_text.trim_suffix("_base")
	var tier_id_text: String = String(tier.tier_id)
	if tier_id_text.begins_with("tier_"):
		tier_id_text = tier_id_text.trim_prefix("tier_")
	if tier_id_text.is_empty():
		return StringName(base_material_id_text)
	return StringName("%s_%s" % [base_material_id_text, tier_id_text])

func _duplicate_animation_effect_stubs(effect_stubs: Array[Resource]) -> Array[Resource]:
	var duplicated_effect_stubs: Array[Resource] = []
	for effect_stub: Resource in effect_stubs:
		if effect_stub == null:
			continue
		var effect_copy: Resource = effect_stub.duplicate(true)
		if effect_copy != null:
			if effect_copy.has_method("normalize"):
				effect_copy.call("normalize")
			duplicated_effect_stubs.append(effect_copy)
	return duplicated_effect_stubs
