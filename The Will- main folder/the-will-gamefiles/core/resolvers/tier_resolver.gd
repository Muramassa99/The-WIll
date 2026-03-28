extends RefCounted
class_name TierResolver

func build_variant(base_material: BaseMaterialDef, tier: TierDef) -> MaterialVariantDef:
	var variant := MaterialVariantDef.new()
	variant.base_material_id = base_material.base_material_id
	variant.tier_id = tier.tier_id
	variant.variant_id = _build_variant_id(base_material, tier)
	variant.variant_stats = _scale_stat_lines(base_material.base_stat_lines, tier.stat_multiplier)
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
	return StringName("%s__%s" % [String(base_material.base_material_id), String(tier.tier_id)])
