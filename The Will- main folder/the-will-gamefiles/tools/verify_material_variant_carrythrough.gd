extends SceneTree

const Fixture = preload("res://tools/forge_v2_small_handle_fixture.gd")
const ForgeServiceScript = preload("res://services/forge_service.gd")
const MaterialRuntimeResolverScript = preload("res://core/resolvers/material_runtime_resolver.gd")

const WoodBaseMaterial: BaseMaterialDef = preload("res://core/defs/materials/base/wood.tres")
const GrayTier: TierDef = preload("res://core/defs/materials/tiers/tier_gray.tres")
const GreenTier: TierDef = preload("res://core/defs/materials/tiers/tier_green.tres")

func _init() -> void:
	var forge_service: ForgeService = ForgeServiceScript.new()
	var material_runtime_resolver = MaterialRuntimeResolverScript.new()
	var material_lookup: Dictionary = Fixture.material_lookup()
	var gray_variant: MaterialVariantDef = forge_service.build_material_variant(WoodBaseMaterial, GrayTier)
	var green_variant: MaterialVariantDef = forge_service.build_material_variant(WoodBaseMaterial, GreenTier)
	material_lookup[gray_variant.variant_id] = gray_variant
	material_lookup[green_variant.variant_id] = green_variant

	var gray_wip := Fixture.build(gray_variant.variant_id, material_lookup)
	var green_wip := Fixture.build(green_variant.variant_id, material_lookup)
	if gray_wip == null or green_wip == null:
		quit(1)
		return
	var gray_profile: BakedProfile = forge_service.bake_wip(gray_wip, material_lookup)
	var green_profile: BakedProfile = forge_service.bake_wip(green_wip, material_lookup)

	var lines: PackedStringArray = []
	lines.append("gray_variant_id=%s" % String(gray_variant.variant_id))
	lines.append("green_variant_id=%s" % String(green_variant.variant_id))
	lines.append("gray_atk_mod_flat=%.4f" % _get_stat_line_value(gray_variant.variant_stats, &"atk_mod_flat"))
	lines.append("green_atk_mod_flat=%.4f" % _get_stat_line_value(green_variant.variant_stats, &"atk_mod_flat"))
	lines.append("green_atk_gt_gray=%s" % str(
		_get_stat_line_value(green_variant.variant_stats, &"atk_mod_flat")
		> _get_stat_line_value(gray_variant.variant_stats, &"atk_mod_flat")
	))
	lines.append("gray_cap_flex=%.4f" % _get_stat_line_value(gray_variant.resolved_capability_bias_lines, &"cap_flex"))
	lines.append("green_cap_flex=%.4f" % _get_stat_line_value(green_variant.resolved_capability_bias_lines, &"cap_flex"))
	lines.append("green_cap_flex_gt_gray=%s" % str(
		_get_stat_line_value(green_variant.resolved_capability_bias_lines, &"cap_flex")
		> _get_stat_line_value(gray_variant.resolved_capability_bias_lines, &"cap_flex")
	))
	lines.append("gray_density=%.4f" % gray_variant.resolved_density_per_cell)
	lines.append("green_density=%.4f" % green_variant.resolved_density_per_cell)
	lines.append("density_equal_between_gray_green=%s" % str(is_equal_approx(
		gray_variant.resolved_density_per_cell,
		green_variant.resolved_density_per_cell
	)))
	lines.append("runtime_resolver_green_base_found=%s" % str(
		material_runtime_resolver.resolve_base_material_for_material_id(green_variant.variant_id, material_lookup) != null
	))
	lines.append("runtime_resolver_green_variant_found=%s" % str(
		material_runtime_resolver.resolve_material_variant_for_material_id(green_variant.variant_id, material_lookup) != null
	))
	lines.append("gray_profile_variant_mix=%s" % JSON.stringify(gray_profile.material_variant_mix))
	lines.append("green_profile_variant_mix=%s" % JSON.stringify(green_profile.material_variant_mix))
	lines.append("gray_profile_atk_mod_flat=%.4f" % _get_stat_line_value(gray_profile.resolved_material_stat_lines, &"atk_mod_flat"))
	lines.append("green_profile_atk_mod_flat=%.4f" % _get_stat_line_value(green_profile.resolved_material_stat_lines, &"atk_mod_flat"))
	lines.append("green_profile_atk_gt_gray=%s" % str(
		_get_stat_line_value(green_profile.resolved_material_stat_lines, &"atk_mod_flat")
		> _get_stat_line_value(gray_profile.resolved_material_stat_lines, &"atk_mod_flat")
	))
	lines.append("gray_profile_cap_flex=%.4f" % _get_stat_line_value(gray_profile.resolved_capability_bias_lines, &"cap_flex"))
	lines.append("green_profile_cap_flex=%.4f" % _get_stat_line_value(green_profile.resolved_capability_bias_lines, &"cap_flex"))
	lines.append("green_profile_cap_flex_gt_gray=%s" % str(
		_get_stat_line_value(green_profile.resolved_capability_bias_lines, &"cap_flex")
		> _get_stat_line_value(gray_profile.resolved_capability_bias_lines, &"cap_flex")
	))
	# Unlike the retired one-cell fixture, this usable 200 mm V2 Handle has
	# 256 cell-equivalents. Both flex totals exceed CapabilityResolver's 1 cap.
	# The strict tier gain is checked above on the unsaturated material totals.
	lines.append("profile_flex_capability_saturation_preserved=%s" % str(
		is_equal_approx(float(green_profile.capability_scores.get(&"cap_flex", 0.0)), 1.0)
		and is_equal_approx(float(gray_profile.capability_scores.get(&"cap_flex", 0.0)), 1.0)
	))
	lines.append("green_profile_mix_contains_green=%s" % str(int(green_profile.material_variant_mix.get(green_variant.variant_id, 0)) > 0))
	lines.append("gray_profile_mix_contains_gray=%s" % str(int(gray_profile.material_variant_mix.get(gray_variant.variant_id, 0)) > 0))

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/material_variant_carrythrough_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	var failed := false
	for line: String in lines:
		if line.ends_with("=false"):
			push_error(line)
			failed = true
	print("Material variant carrythrough: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func _get_stat_line_value(stat_lines: Array[StatLine], stat_id: StringName) -> float:
	for stat_line: StatLine in stat_lines:
		if stat_line == null or stat_line.stat_id != stat_id or not stat_line.is_numeric():
			continue
		return stat_line.value
	return 0.0
