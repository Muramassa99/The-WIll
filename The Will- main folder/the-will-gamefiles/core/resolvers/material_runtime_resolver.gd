extends RefCounted
class_name MaterialRuntimeResolver

const TierResolverScript = preload("res://core/resolvers/tier_resolver.gd")
const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const DEFAULT_TIER_REGISTRY_RESOURCE: Resource = preload("res://core/defs/materials/tiers/tier_registry_default.tres")

var tier_resolver: TierResolver = TierResolverScript.new()
var tier_registry_def: Resource = DEFAULT_TIER_REGISTRY_RESOURCE

func _init(registry_def: Resource = null) -> void:
	tier_registry_def = registry_def if registry_def != null else DEFAULT_TIER_REGISTRY_RESOURCE

func resolve_material_variant_for_cell(cell: CellAtom, material_lookup: Dictionary) -> MaterialVariantDef:
	if cell == null:
		return null
	return resolve_material_variant_for_material_id(cell.material_variant_id, material_lookup)

func resolve_material_variant_for_material_id(material_id: StringName, material_lookup: Dictionary) -> MaterialVariantDef:
	if material_id == StringName():
		return null
	if CraftedItemWIPScript.is_builder_marker_material_id(material_id):
		return null
	var material_entry: Variant = material_lookup.get(material_id)
	if material_entry is MaterialVariantDef:
		return material_entry as MaterialVariantDef

	var derived_variant: MaterialVariantDef = _build_variant_from_material_id(material_id, material_lookup)
	if derived_variant == null:
		return null
	material_lookup[material_id] = derived_variant
	return derived_variant

func resolve_base_material_for_cell(cell: CellAtom, material_lookup: Dictionary) -> BaseMaterialDef:
	if cell == null:
		return null
	return resolve_base_material_for_material_id(cell.material_variant_id, material_lookup)

func resolve_base_material_for_material_id(material_id: StringName, material_lookup: Dictionary) -> BaseMaterialDef:
	if material_id == StringName():
		return null
	if CraftedItemWIPScript.is_builder_marker_material_id(material_id):
		return null
	var material_entry: Variant = material_lookup.get(material_id)
	if material_entry is BaseMaterialDef:
		return material_entry as BaseMaterialDef
	var material_variant: MaterialVariantDef = resolve_material_variant_for_material_id(material_id, material_lookup)
	if material_variant != null:
		return material_lookup.get(material_variant.base_material_id) as BaseMaterialDef
	return null

func resolve_density_per_cell(cell: CellAtom, material_lookup: Dictionary) -> float:
	var material_variant: MaterialVariantDef = resolve_material_variant_for_cell(cell, material_lookup)
	if material_variant != null and material_variant.resolved_density_per_cell > 0.0:
		return material_variant.resolved_density_per_cell
	var base_material: BaseMaterialDef = resolve_base_material_for_cell(cell, material_lookup)
	if base_material == null:
		return 0.0
	return base_material.density_per_cell

func resolve_material_stat_lines_for_cell(cell: CellAtom, material_lookup: Dictionary) -> Array[StatLine]:
	var material_variant: MaterialVariantDef = resolve_material_variant_for_cell(cell, material_lookup)
	if material_variant != null and not material_variant.variant_stats.is_empty():
		return _copy_stat_lines(material_variant.variant_stats)
	var base_material: BaseMaterialDef = resolve_base_material_for_cell(cell, material_lookup)
	if base_material == null:
		return []
	return _copy_stat_lines(base_material.base_stat_lines)

func resolve_capability_bias_lines_for_cell(cell: CellAtom, material_lookup: Dictionary) -> Array[StatLine]:
	var material_variant: MaterialVariantDef = resolve_material_variant_for_cell(cell, material_lookup)
	if material_variant != null and not material_variant.resolved_capability_bias_lines.is_empty():
		return _copy_stat_lines(material_variant.resolved_capability_bias_lines)
	var base_material: BaseMaterialDef = resolve_base_material_for_cell(cell, material_lookup)
	if base_material == null:
		return []
	return _copy_stat_lines(base_material.capability_bias_lines)

func resolve_skill_family_bias_lines_for_cell(cell: CellAtom, material_lookup: Dictionary) -> Array[StatLine]:
	var material_variant: MaterialVariantDef = resolve_material_variant_for_cell(cell, material_lookup)
	if material_variant != null and not material_variant.resolved_skill_family_bias_lines.is_empty():
		return _copy_stat_lines(material_variant.resolved_skill_family_bias_lines)
	var base_material: BaseMaterialDef = resolve_base_material_for_cell(cell, material_lookup)
	if base_material == null:
		return []
	return _copy_stat_lines(base_material.skill_family_bias_lines)

func resolve_elemental_affinity_lines_for_cell(cell: CellAtom, material_lookup: Dictionary) -> Array[StatLine]:
	var material_variant: MaterialVariantDef = resolve_material_variant_for_cell(cell, material_lookup)
	if material_variant != null and not material_variant.resolved_elemental_affinity_lines.is_empty():
		return _copy_stat_lines(material_variant.resolved_elemental_affinity_lines)
	var base_material: BaseMaterialDef = resolve_base_material_for_cell(cell, material_lookup)
	if base_material == null:
		return []
	return _copy_stat_lines(base_material.elemental_affinity_lines)

func resolve_equipment_context_bias_lines_for_cell(cell: CellAtom, material_lookup: Dictionary) -> Array[StatLine]:
	var material_variant: MaterialVariantDef = resolve_material_variant_for_cell(cell, material_lookup)
	if material_variant != null and not material_variant.resolved_equipment_context_bias_lines.is_empty():
		return _copy_stat_lines(material_variant.resolved_equipment_context_bias_lines)
	var base_material: BaseMaterialDef = resolve_base_material_for_cell(cell, material_lookup)
	if base_material == null:
		return []
	return _copy_stat_lines(base_material.equipment_context_bias_lines)

func has_positive_capability_bias_for_cell(cell: CellAtom, material_lookup: Dictionary, capability_id: StringName) -> bool:
	for bias_line: StatLine in resolve_capability_bias_lines_for_cell(cell, material_lookup):
		if bias_line == null:
			continue
		if bias_line.stat_id != capability_id:
			continue
		if not bias_line.is_numeric():
			continue
		if bias_line.value > 0.0:
			return true
	return false

func resolve_material_color(material_id: StringName, material_lookup: Dictionary, fallback_color: Color) -> Color:
	if CraftedItemWIPScript.is_builder_marker_material_id(material_id):
		return CraftedItemWIPScript.get_builder_marker_color(material_id)
	var base_material: BaseMaterialDef = resolve_base_material_for_material_id(material_id, material_lookup)
	if base_material != null:
		return base_material.albedo_color
	return fallback_color

func _copy_stat_lines(stat_lines: Array[StatLine]) -> Array[StatLine]:
	var copied_lines: Array[StatLine] = []
	for stat_line: StatLine in stat_lines:
		if stat_line == null:
			continue
		copied_lines.append(stat_line.copy_scaled(1.0))
	return copied_lines

func _build_variant_from_material_id(material_id: StringName, material_lookup: Dictionary) -> MaterialVariantDef:
	var base_material: BaseMaterialDef = _resolve_base_material_from_variant_id(material_id, material_lookup)
	var tier_def: TierDef = _resolve_tier_from_variant_id(material_id)
	if base_material == null or tier_def == null:
		return null
	return tier_resolver.build_variant(base_material, tier_def)

func _resolve_base_material_from_variant_id(material_id: StringName, material_lookup: Dictionary) -> BaseMaterialDef:
	var material_id_text: String = String(material_id)
	if not material_id_text.begins_with("mat_") or material_id_text.ends_with("_base"):
		return null
	var tier_separator_index: int = material_id_text.rfind("_")
	if tier_separator_index <= 0:
		return null
	var base_material_id: StringName = StringName("%s_base" % material_id_text.substr(0, tier_separator_index))
	return material_lookup.get(base_material_id) as BaseMaterialDef

func _resolve_tier_from_variant_id(material_id: StringName) -> TierDef:
	var material_id_text: String = String(material_id)
	var tier_separator_index: int = material_id_text.rfind("_")
	if tier_separator_index <= 0:
		return null
	var tier_id: StringName = StringName(material_id_text.substr(tier_separator_index + 1))
	if tier_id == StringName():
		return null
	for tier_def: TierDef in _get_tier_defs():
		if tier_def == null:
			continue
		if tier_def.tier_id == tier_id:
			return tier_def
	return null

func _get_tier_defs() -> Array[TierDef]:
	var tier_defs: Array[TierDef] = []
	var registry_def = tier_registry_def
	if registry_def == null or registry_def.is_empty():
		return tier_defs
	for tier_def: TierDef in registry_def.entries:
		if tier_def == null:
			continue
		tier_defs.append(tier_def)
	return tier_defs
