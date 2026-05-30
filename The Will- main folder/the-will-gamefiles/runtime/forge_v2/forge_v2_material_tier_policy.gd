extends RefCounted
class_name ForgeV2MaterialTierPolicy

const TIER_GRAY := &"gray"
const TIER_GREEN := &"green"
const TIER_BLUE := &"blue"
const TIER_PURPLE := &"purple"
const TIER_ORANGE := &"orange"

const DEFAULT_MAX_MATERIAL_TIER_SPAN := 2
const DEFAULT_MIN_UPGRADE_STEP := 0
const DEFAULT_MAX_UPGRADE_STEP := 2

static func get_tier_ids_in_order() -> Array[StringName]:
	return [
		TIER_GRAY,
		TIER_GREEN,
		TIER_BLUE,
		TIER_PURPLE,
		TIER_ORANGE,
	]

static func normalize_tier_id(tier_id: StringName) -> StringName:
	if get_tier_ids_in_order().has(tier_id):
		return tier_id
	return TIER_GRAY

static func get_tier_index(tier_id: StringName) -> int:
	return get_tier_ids_in_order().find(normalize_tier_id(tier_id))

static func extract_tier_id_from_material_variant_id(material_variant_id: StringName) -> StringName:
	var text: String = String(material_variant_id)
	for tier_id: StringName in get_tier_ids_in_order():
		if text.ends_with("_%s" % String(tier_id)):
			return tier_id
	return TIER_GRAY

static func are_tiers_mix_compatible(
	tier_ids: Array[StringName],
	max_tier_span: int = DEFAULT_MAX_MATERIAL_TIER_SPAN
) -> bool:
	return build_tier_mix_validation(tier_ids, max_tier_span).get("valid", false)

static func are_material_variants_mix_compatible(
	material_variant_ids: Array[StringName],
	max_tier_span: int = DEFAULT_MAX_MATERIAL_TIER_SPAN
) -> bool:
	var tier_ids: Array[StringName] = []
	for material_variant_id: StringName in material_variant_ids:
		tier_ids.append(extract_tier_id_from_material_variant_id(material_variant_id))
	return are_tiers_mix_compatible(tier_ids, max_tier_span)

static func build_tier_mix_validation(
	tier_ids: Array[StringName],
	max_tier_span: int = DEFAULT_MAX_MATERIAL_TIER_SPAN
) -> Dictionary:
	if tier_ids.is_empty():
		return {
			"valid": true,
			"tier_span": 0,
			"min_tier": StringName(),
			"max_tier": StringName(),
			"reason": "empty_mix",
		}
	var min_index: int = 999999
	var max_index: int = -999999
	var normalized_tiers: Array[StringName] = []
	for tier_id: StringName in tier_ids:
		var normalized_tier: StringName = normalize_tier_id(tier_id)
		normalized_tiers.append(normalized_tier)
		var tier_index: int = get_tier_index(normalized_tier)
		min_index = mini(min_index, tier_index)
		max_index = maxi(max_index, tier_index)
	var tier_span: int = max_index - min_index
	var valid: bool = tier_span <= maxi(max_tier_span, 0)
	var ordered_tiers: Array[StringName] = get_tier_ids_in_order()
	return {
		"valid": valid,
		"tier_span": tier_span,
		"min_tier": ordered_tiers[min_index],
		"max_tier": ordered_tiers[max_index],
		"normalized_tiers": normalized_tiers,
		"reason": "ok" if valid else "tier_span_too_wide",
	}

static func can_upgrade_blueprint_tier(
	source_tier_id: StringName,
	replacement_tier_id: StringName,
	min_upgrade_step: int = DEFAULT_MIN_UPGRADE_STEP,
	max_upgrade_step: int = DEFAULT_MAX_UPGRADE_STEP
) -> bool:
	var source_index: int = get_tier_index(source_tier_id)
	var replacement_index: int = get_tier_index(replacement_tier_id)
	var upgrade_step: int = replacement_index - source_index
	return upgrade_step >= min_upgrade_step and upgrade_step <= max_upgrade_step

static func build_allowed_blueprint_replacement_tiers(
	source_tier_id: StringName,
	min_upgrade_step: int = DEFAULT_MIN_UPGRADE_STEP,
	max_upgrade_step: int = DEFAULT_MAX_UPGRADE_STEP
) -> Array[StringName]:
	var source_index: int = get_tier_index(source_tier_id)
	var tier_ids: Array[StringName] = get_tier_ids_in_order()
	var allowed_tiers: Array[StringName] = []
	for tier_index in range(tier_ids.size()):
		var upgrade_step: int = tier_index - source_index
		if upgrade_step >= min_upgrade_step and upgrade_step <= max_upgrade_step:
			allowed_tiers.append(tier_ids[tier_index])
	return allowed_tiers

static func build_compatible_three_tier_windows() -> Array[Array]:
	var tier_ids: Array[StringName] = get_tier_ids_in_order()
	var windows: Array[Array] = []
	for start_index in range(0, maxi(tier_ids.size() - DEFAULT_MAX_MATERIAL_TIER_SPAN, 0)):
		var window: Array[StringName] = []
		for offset in range(DEFAULT_MAX_MATERIAL_TIER_SPAN + 1):
			window.append(tier_ids[start_index + offset])
		windows.append(window)
	return windows

static func build_policy_summary() -> Dictionary:
	return {
		"tier_order": get_tier_ids_in_order(),
		"max_material_tier_span": DEFAULT_MAX_MATERIAL_TIER_SPAN,
		"max_upgrade_step": DEFAULT_MAX_UPGRADE_STEP,
		"compatible_three_tier_windows": build_compatible_three_tier_windows(),
		"notes": [
			"Blueprint visuals are authored once; upgrades replace material quality within the same design.",
			"Creation and blueprint upgrade material mixes may use one tier, two adjacent tiers, or one three-tier window.",
			"Allowed three-tier windows are gray/green/blue, green/blue/purple, and blue/purple/orange.",
			"VOID is not a real material tier and does not participate in mix distance checks.",
		],
	}
