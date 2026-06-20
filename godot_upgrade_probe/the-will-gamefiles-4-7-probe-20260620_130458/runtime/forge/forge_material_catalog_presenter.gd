extends RefCounted
class_name ForgeMaterialCatalogPresenter

const MaterialRuntimeResolverScript = preload("res://core/resolvers/material_runtime_resolver.gd")

var material_runtime_resolver = MaterialRuntimeResolverScript.new()

func build_material_catalog(
	forge_controller: ForgeGridController,
	inventory_state: PlayerForgeInventoryState,
	material_lookup: Dictionary
) -> Array[Dictionary]:
	var material_catalog: Array[Dictionary] = []
	if forge_controller == null:
		return material_catalog
	material_catalog.append_array(_build_builder_marker_entries(forge_controller))
	var material_ids: Array[StringName] = _collect_material_catalog_ids(forge_controller, inventory_state)
	for material_id: StringName in material_ids:
		var material_entry: Variant = _resolve_material_entry(material_id, material_lookup)
		var base_material: BaseMaterialDef = material_runtime_resolver.resolve_base_material_for_material_id(material_id, material_lookup)
		if base_material == null:
			continue
		var quantity: int = inventory_state.get_quantity(material_id) if inventory_state != null else 0
		material_catalog.append({
			"material_id": material_id,
			"material_entry": material_entry,
			"base_material": base_material,
			"quantity": quantity,
			"display_name": _resolve_material_display_name(base_material, material_entry),
		})
	return material_catalog

func reconcile_selection(material_catalog: Array[Dictionary], selected_material_id: StringName, armed_material_id: StringName) -> Dictionary:
	if material_catalog.is_empty():
		return {
			"selected_material_variant_id": StringName(),
			"armed_material_variant_id": StringName(),
		}
	var resolved_selected_material_id: StringName = selected_material_id
	var resolved_armed_material_id: StringName = armed_material_id
	var selected_entry: Dictionary = get_material_entry(material_catalog, resolved_selected_material_id)
	if selected_entry.is_empty():
		resolved_selected_material_id = _get_default_selected_material_id(material_catalog)
		selected_entry = get_material_entry(material_catalog, resolved_selected_material_id)
	if not _is_placeable_without_inventory(selected_entry) and int(selected_entry.get("quantity", 0)) <= 0 and resolved_armed_material_id == resolved_selected_material_id:
		resolved_armed_material_id = StringName()
	var armed_entry: Dictionary = get_material_entry(material_catalog, resolved_armed_material_id)
	if resolved_armed_material_id != StringName() and not _is_placeable_without_inventory(armed_entry) and int(armed_entry.get("quantity", 0)) <= 0:
		resolved_armed_material_id = StringName()
	if resolved_armed_material_id == StringName() and int(selected_entry.get("quantity", 0)) > 0:
		resolved_armed_material_id = resolved_selected_material_id
	return {
		"selected_material_variant_id": resolved_selected_material_id,
		"armed_material_variant_id": resolved_armed_material_id,
	}

func build_visible_inventory_entries(material_catalog: Array[Dictionary], current_inventory_page: StringName, search_text: String) -> Array[Dictionary]:
	var visible_inventory_entries: Array[Dictionary] = []
	var normalized_search_text: String = search_text.strip_edges().to_lower()
	for entry: Dictionary in material_catalog:
		if _is_builder_marker(entry):
			visible_inventory_entries.append(entry)
			continue
		var quantity: int = int(entry.get("quantity", 0))
		var display_name: String = String(entry.get("display_name", ""))
		var base_material: BaseMaterialDef = entry.get("base_material") as BaseMaterialDef
		if current_inventory_page == &"owned" and quantity <= 0:
			continue
		if current_inventory_page == &"weapon" and not _supports_weapon_context(base_material):
			continue
		if not normalized_search_text.is_empty():
			var haystack: String = "%s %s" % [display_name.to_lower(), String(entry.get("material_id", &"")).to_lower()]
			if not haystack.contains(normalized_search_text):
				continue
		visible_inventory_entries.append(entry)
	return visible_inventory_entries

func get_material_entry(material_catalog: Array[Dictionary], material_id: StringName) -> Dictionary:
	for entry: Dictionary in material_catalog:
		if entry.get("material_id", &"") == material_id:
			return entry
	return {}

func build_material_description_text(entry: Dictionary) -> String:
	if entry.is_empty():
		return "Select a material entry to inspect it."
	if _is_builder_marker(entry):
		return "\n".join([
			"[b]%s[/b]" % String(entry.get("display_name", "Builder Marker")),
			"Marker id: %s" % String(entry.get("material_id", &"")),
			"",
			"Ranged bow authoring marker.",
			"Place one of each endpoint pair to define runtime string anchors.",
			"Does not consume forge inventory and is filtered out of baked geometry.",
		])
	var base_material: BaseMaterialDef = entry.get("base_material") as BaseMaterialDef
	var material_variant: MaterialVariantDef = entry.get("material_entry") as MaterialVariantDef
	var quantity: int = int(entry.get("quantity", 0))
	var lines: PackedStringArray = []
	lines.append("[b]%s[/b]" % String(entry.get("display_name", "Unknown Material")))
	lines.append("Material id: %s" % String(entry.get("material_id", &"")))
	lines.append("Owned quantity: %d" % quantity)
	lines.append("Family: %s" % String(base_material.material_family if base_material != null else &"unknown"))
	if material_variant != null:
		lines.append("Quality: %s" % _format_tier_display_name(material_variant.tier_id))
	lines.append("")
	lines.append("Processed forge material for the weapon station.")
	lines.append("Readable even when quantity is zero; placeable only when owned.")
	if base_material != null:
		lines.append("Good at: %s" % _describe_material_strengths(base_material))
		lines.append("Tradeoffs: %s" % _describe_material_tradeoffs(base_material))
		lines.append("Source note: processed from world drops through Forge material conversion.")
	return "\n".join(lines)

func build_material_stats_text(entry: Dictionary) -> String:
	if entry.is_empty():
		return ""
	if _is_builder_marker(entry):
		return "\n".join([
			"[b]Builder Marker[/b]",
			"pair = %s" % String(entry.get("builder_marker_pair_id", &"")).to_upper(),
			"endpoint = %d" % int(entry.get("builder_marker_endpoint_index", 0)),
			"inventory_backed = false",
			"baked_into_mass = false",
			"baked_into_segments = false",
			"runtime_string_anchor = true",
		])
	var base_material: BaseMaterialDef = entry.get("base_material") as BaseMaterialDef
	var material_variant: MaterialVariantDef = entry.get("material_entry") as MaterialVariantDef
	var stat_lines: PackedStringArray = []
	if base_material != null:
		if material_variant != null:
			stat_lines.append("[b]Resolved Variant Stats[/b]")
			stat_lines.append("tier = %s" % _format_tier_display_name(material_variant.tier_id))
			stat_lines.append("resolved_density_per_cell = %.3f" % material_variant.resolved_density_per_cell)
			stat_lines.append("resolved_value_multiplier = %.3f" % material_variant.resolved_value_score)
			stat_lines.append("resolved_processing_output_count = %d" % material_variant.resolved_processing_output_count)
			stat_lines.append("")
			if not material_variant.variant_stats.is_empty():
				stat_lines.append("[b]Resolved Material Stat Lines[/b]")
				for stat_line: StatLine in material_variant.variant_stats:
					if stat_line == null:
						continue
					stat_lines.append(_format_stat_line(stat_line))
				stat_lines.append("")
			if not material_variant.resolved_capability_bias_lines.is_empty():
				stat_lines.append("[b]Resolved Capability Bias Lines[/b]")
				for stat_line: StatLine in material_variant.resolved_capability_bias_lines:
					if stat_line == null:
						continue
					stat_lines.append(_format_stat_line(stat_line))
				stat_lines.append("")
			if not material_variant.resolved_skill_family_bias_lines.is_empty():
				stat_lines.append("[b]Resolved Skill Family Bias Lines[/b]")
				for stat_line: StatLine in material_variant.resolved_skill_family_bias_lines:
					if stat_line == null:
						continue
					stat_lines.append(_format_stat_line(stat_line))
				stat_lines.append("")
			if not material_variant.resolved_elemental_affinity_lines.is_empty():
				stat_lines.append("[b]Resolved Elemental Affinity Lines[/b]")
				for stat_line: StatLine in material_variant.resolved_elemental_affinity_lines:
					if stat_line == null:
						continue
					stat_lines.append(_format_stat_line(stat_line))
				stat_lines.append("")
			if not material_variant.resolved_equipment_context_bias_lines.is_empty():
				stat_lines.append("[b]Resolved Equipment Context Bias Lines[/b]")
				for stat_line: StatLine in material_variant.resolved_equipment_context_bias_lines:
					if stat_line == null:
						continue
					stat_lines.append(_format_stat_line(stat_line))
				stat_lines.append("")
		stat_lines.append("[b]Base Physical Truth[/b]")
		stat_lines.append("density_per_cell = %.3f" % base_material.density_per_cell)
		stat_lines.append("hardness = %.3f" % base_material.hardness)
		stat_lines.append("toughness = %.3f" % base_material.toughness)
		stat_lines.append("elasticity = %.3f" % base_material.elasticity)
		stat_lines.append("")
		stat_lines.append("[b]Base Support Flags[/b]")
		stat_lines.append("anchor=%s edge=%s blunt=%s guard=%s plate=%s" % [
			_format_bool(base_material.can_be_anchor_material),
			_format_bool(base_material.can_be_beveled_edge),
			_format_bool(base_material.can_be_blunt_surface),
			_format_bool(base_material.can_be_guard_surface),
			_format_bool(base_material.can_be_plate_surface)
		])
		stat_lines.append("joint=%s bow_limb=%s bow_string=%s projectile=%s" % [
			_format_bool(base_material.can_be_joint_support or base_material.can_be_joint_membrane),
			_format_bool(base_material.can_be_bow_limb),
			_format_bool(base_material.can_be_bow_string),
			_format_bool(base_material.can_be_projectile_support)
		])
	return "\n".join(stat_lines)

func get_selected_display_name(material_catalog: Array[Dictionary], selected_material_id: StringName) -> String:
	var entry: Dictionary = get_material_entry(material_catalog, selected_material_id)
	if entry.is_empty():
		return "none"
	return String(entry.get("display_name", "none"))

func get_armed_display_name(material_catalog: Array[Dictionary], armed_material_id: StringName) -> String:
	var entry: Dictionary = get_material_entry(material_catalog, armed_material_id)
	if entry.is_empty():
		return "none"
	return String(entry.get("display_name", "none"))

func _collect_material_catalog_ids(forge_controller: ForgeGridController, inventory_state: PlayerForgeInventoryState) -> Array[StringName]:
	var ordered_material_ids: Array[StringName] = []
	if forge_controller != null:
		ordered_material_ids = forge_controller.get_material_catalog_ids()
	var extra_material_ids: Array[StringName] = []
	if inventory_state == null:
		return ordered_material_ids
	for stack: ForgeMaterialStack in inventory_state.material_stacks:
		if stack == null or stack.material_variant_id == StringName() or stack.quantity <= 0:
			continue
		if ordered_material_ids.has(stack.material_variant_id) or extra_material_ids.has(stack.material_variant_id):
			continue
		extra_material_ids.append(stack.material_variant_id)
	extra_material_ids.sort()
	ordered_material_ids.append_array(extra_material_ids)
	return ordered_material_ids

func _build_builder_marker_entries(forge_controller: ForgeGridController) -> Array[Dictionary]:
	if forge_controller == null or forge_controller.active_wip == null:
		return []
	return CraftedItemWIP.get_builder_marker_catalog_entries(
		forge_controller.active_wip.forge_builder_path_id,
		forge_controller.active_wip.forge_builder_component_id
	)

func _get_default_selected_material_id(material_catalog: Array[Dictionary]) -> StringName:
	for entry: Dictionary in material_catalog:
		if _is_builder_marker(entry):
			continue
		if int(entry.get("quantity", 0)) <= 0:
			continue
		return entry.get("material_id", &"")
	for entry: Dictionary in material_catalog:
		if _is_builder_marker(entry):
			continue
		return entry.get("material_id", &"")
	if material_catalog.is_empty():
		return StringName()
	return material_catalog[0].get("material_id", &"")

func _is_builder_marker(entry: Dictionary) -> bool:
	return bool(entry.get("is_builder_marker", false))

func _is_placeable_without_inventory(entry: Dictionary) -> bool:
	return bool(entry.get("is_placeable_without_inventory", false))

func _resolve_material_entry(material_id: StringName, material_lookup: Dictionary) -> Variant:
	var material_entry: Variant = material_lookup.get(material_id)
	if material_entry != null:
		return material_entry
	return material_runtime_resolver.resolve_material_variant_for_material_id(material_id, material_lookup)

func _supports_weapon_context(base_material: BaseMaterialDef) -> bool:
	if base_material == null:
		return false
	for stat_line: StatLine in base_material.equipment_context_bias_lines:
		if stat_line == null:
			continue
		if stat_line.stat_id == &"ctx_weapon":
			return true
	return false

func _resolve_material_display_name(base_material: BaseMaterialDef, material_entry: Variant = null) -> String:
	if base_material == null:
		return "Unknown Material"
	var base_name: String = base_material.display_name
	if base_name.is_empty():
		var raw_text: String = String(base_material.base_material_id).replace("mat_", "").replace("_base", "").replace("_", " ")
		base_name = raw_text.capitalize()
	if material_entry is MaterialVariantDef:
		var material_variant: MaterialVariantDef = material_entry as MaterialVariantDef
		var tier_display_name: String = _format_tier_display_name(material_variant.tier_id)
		if not tier_display_name.is_empty():
			return "%s (%s)" % [base_name, tier_display_name]
	return base_name

func _format_tier_display_name(tier_id: StringName) -> String:
	var tier_id_text: String = String(tier_id)
	if tier_id_text.begins_with("tier_"):
		tier_id_text = tier_id_text.trim_prefix("tier_")
	return tier_id_text.capitalize()

func _describe_material_strengths(base_material: BaseMaterialDef) -> String:
	var strengths: PackedStringArray = []
	if base_material.can_be_anchor_material:
		strengths.append("anchor stability")
	if base_material.can_be_bow_limb:
		strengths.append("limb flex")
	if base_material.can_be_bow_string:
		strengths.append("string support")
	if base_material.can_be_beveled_edge:
		strengths.append("edge shaping")
	if base_material.can_be_blunt_surface:
		strengths.append("blunt impact")
	if strengths.is_empty():
		return "general structural use"
	return ", ".join(strengths)

func _describe_material_tradeoffs(base_material: BaseMaterialDef) -> String:
	if base_material == null:
		return "unknown"
	if base_material.elasticity < 0.3:
		return "low flex compared to lighter materials"
	if base_material.hardness < 0.5:
		return "lower hardness than heavy structural metals"
	return "balanced first-slice baseline tradeoffs"

func _format_stat_line(stat_line: StatLine) -> String:
	if stat_line == null:
		return ""
	var suffix: String = ""
	if stat_line.value_kind == StatLine.ValueKind.PCT_ADD:
		suffix = " (pct)"
	return "%s = %.3f%s" % [String(stat_line.stat_id), stat_line.value, suffix]

func _format_bool(value: bool) -> String:
	return "true" if value else "false"
