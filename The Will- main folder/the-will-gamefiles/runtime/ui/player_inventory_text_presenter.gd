extends RefCounted
class_name PlayerInventoryTextPresenter

func format_equipped_entry_label(equipped_entry) -> String:
	if equipped_entry == null:
		return "Empty"
	var suffix: String = ""
	if equipped_entry.is_forge_test_wip():
		suffix = " [Forge Test]"
	elif equipped_entry.is_stored_item():
		suffix = " [Item]"
	return "%s%s" % [equipped_entry.get_resolved_display_name(), suffix]

func format_stored_item_label(stored_item: Resource) -> String:
	if stored_item == null:
		return "Unknown Item"
	return "%s x%d" % [stored_item.get_resolved_display_name(), maxi(stored_item.stack_count, 1)]

func format_material_stack_label(material_stack: ForgeMaterialStack, material_lookup: Dictionary) -> String:
	if material_stack == null:
		return "Unknown Material"
	return "%s x%d" % [resolve_material_variant_display_name(material_stack.material_variant_id, material_lookup), material_stack.quantity]

func resolve_material_variant_display_name(material_variant_id: StringName, material_lookup: Dictionary) -> String:
	var material_id_text: String = String(material_variant_id)
	if material_id_text.is_empty():
		return "Unknown Material"
	var tier_separator_index: int = material_id_text.rfind("_")
	var tier_display_name: String = ""
	if tier_separator_index > 0:
		tier_display_name = material_id_text.substr(tier_separator_index + 1).capitalize()
	var base_material_id: StringName = StringName("%s_base" % material_id_text.substr(0, tier_separator_index))
	var base_material: BaseMaterialDef = material_lookup.get(base_material_id) as BaseMaterialDef
	if base_material == null:
		return material_id_text
	if tier_display_name.is_empty():
		return base_material.display_name
	return "%s (%s)" % [base_material.display_name, tier_display_name]

func format_wip_label(saved_wip: CraftedItemWIP, is_selected_for_forge: bool) -> String:
	var prefix: String = "* " if is_selected_for_forge else ""
	return "%s%s" % [prefix, get_wip_display_name(saved_wip)]

func get_wip_display_name(saved_wip: CraftedItemWIP) -> String:
	if saved_wip == null:
		return "Unnamed WIP"
	var cleaned_name: String = saved_wip.forge_project_name.strip_edges()
	if not cleaned_name.is_empty():
		return cleaned_name
	return String(saved_wip.wip_id)

func count_wip_cells(saved_wip: CraftedItemWIP) -> int:
	if saved_wip == null:
		return 0
	var total_cells: int = 0
	for layer_atom: LayerAtom in saved_wip.layers:
		if layer_atom == null:
			continue
		total_cells += layer_atom.cells.size()
	return total_cells
