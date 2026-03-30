extends RefCounted
class_name ProcessResolver

func build_stack(process_rule: ProcessRuleDef, material_variant: MaterialVariantDef) -> ForgeMaterialStack:
	var stack := ForgeMaterialStack.new()
	stack.stack_id = _build_stack_id(process_rule, material_variant)
	stack.material_variant_id = material_variant.variant_id
	stack.quantity = process_rule.output_count_per_input
	stack.variant_stats = _copy_stat_lines(material_variant.variant_stats)
	return stack

func _copy_stat_lines(stat_lines: Array[StatLine]) -> Array[StatLine]:
	var copied_lines: Array[StatLine] = []
	for stat_line in stat_lines:
		if stat_line == null:
			continue
		copied_lines.append(stat_line.copy_scaled(1.0))
	return copied_lines

func _build_stack_id(process_rule: ProcessRuleDef, material_variant: MaterialVariantDef) -> StringName:
	if process_rule == null and material_variant == null:
		return StringName()
	if process_rule == null:
		return StringName("stack_%s" % String(material_variant.variant_id))
	if material_variant == null:
		return StringName("stack_%s" % String(process_rule.rule_id))
	return StringName("stack_%s__%s" % [String(process_rule.rule_id), String(material_variant.variant_id)])
