extends RefCounted
class_name DisassemblyBenchTextPresenter

func refresh_material_lookup(material_pipeline_service) -> Dictionary:
	return material_pipeline_service.call("build_base_material_lookup")

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

func get_selected_stack_total(selected_item_ids: Array[StringName], body_inventory_state) -> int:
	var total: int = 0
	for item_instance_id: StringName in selected_item_ids:
		var stored_item = body_inventory_state.call("get_item", item_instance_id) if body_inventory_state != null else null
		if stored_item == null:
			continue
		total += maxi(stored_item.stack_count, 0)
	return total
