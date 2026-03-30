extends SceneTree

const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const ForgeServiceScript = preload("res://services/forge_service.gd")
const MaterialRuntimeResolverScript = preload("res://core/resolvers/material_runtime_resolver.gd")

const WoodBaseMaterial: BaseMaterialDef = preload("res://core/defs/materials/base/wood.tres")
const GrayTier: TierDef = preload("res://core/defs/materials/tiers/tier_gray.tres")
const GreenTier: TierDef = preload("res://core/defs/materials/tiers/tier_green.tres")

func _init() -> void:
	var forge_service: ForgeService = ForgeServiceScript.new()
	var material_runtime_resolver = MaterialRuntimeResolverScript.new()
	var controller: ForgeGridController = ForgeGridControllerScript.new()
	var material_lookup: Dictionary = controller.build_default_material_lookup()
	var gray_variant: MaterialVariantDef = forge_service.build_material_variant(WoodBaseMaterial, GrayTier)
	var green_variant: MaterialVariantDef = forge_service.build_material_variant(WoodBaseMaterial, GreenTier)
	material_lookup[gray_variant.variant_id] = gray_variant
	material_lookup[green_variant.variant_id] = green_variant

	var gray_profile: BakedProfile = forge_service.bake_wip(_build_single_cell_wip(&"verify_gray", gray_variant.variant_id), material_lookup)
	var green_profile: BakedProfile = forge_service.bake_wip(_build_single_cell_wip(&"verify_green", green_variant.variant_id), material_lookup)

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
	lines.append("green_profile_flex_capability_gt_gray=%s" % str(
		float(green_profile.capability_scores.get(&"cap_flex", 0.0))
		> float(gray_profile.capability_scores.get(&"cap_flex", 0.0))
	))
	lines.append("green_profile_mix_contains_green=%s" % str(int(green_profile.material_variant_mix.get(green_variant.variant_id, 0)) == 1))
	lines.append("gray_profile_mix_contains_gray=%s" % str(int(gray_profile.material_variant_mix.get(gray_variant.variant_id, 0)) == 1))

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/material_variant_carrythrough_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	controller.free()
	quit()

func _build_single_cell_wip(wip_id: StringName, material_variant_id: StringName) -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = wip_id
	wip.forge_project_name = String(wip_id)
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"

	var layer: LayerAtom = LayerAtom.new()
	layer.layer_index = 20
	layer.cells = []

	var cell: CellAtom = CellAtom.new()
	cell.grid_position = Vector3i(0, 0, 20)
	cell.layer_index = 20
	cell.material_variant_id = material_variant_id
	layer.cells.append(cell)

	wip.layers = [layer]
	return wip

func _get_stat_line_value(stat_lines: Array[StatLine], stat_id: StringName) -> float:
	for stat_line: StatLine in stat_lines:
		if stat_line == null or stat_line.stat_id != stat_id or not stat_line.is_numeric():
			continue
		return stat_line.value
	return 0.0
