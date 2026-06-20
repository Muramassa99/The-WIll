extends RefCounted
class_name SalvageService

const InventoryStorageServiceScript = preload("res://services/inventory_storage_service.gd")
const MaterialPipelineServiceScript = preload("res://services/material_pipeline_service.gd")
const SalvageResultScript = preload("res://core/models/salvage_result.gd")

const DEFAULT_SALVAGE_RULES_RESOURCE: Resource = preload("res://core/defs/forge/salvage_rules_default.tres")
const DEFAULT_SKILL_CORE_RULES_RESOURCE: Resource = preload("res://core/defs/forge/skill_core_rules_default.tres")

var salvage_rules_def: Resource = DEFAULT_SALVAGE_RULES_RESOURCE
var skill_core_rules_def: Resource = DEFAULT_SKILL_CORE_RULES_RESOURCE
var inventory_storage_service = InventoryStorageServiceScript.new()
var material_pipeline_service = MaterialPipelineServiceScript.new()

func _init(rules_def: Resource = null, core_rules_def: Resource = null) -> void:
	salvage_rules_def = rules_def if rules_def != null else DEFAULT_SALVAGE_RULES_RESOURCE
	skill_core_rules_def = core_rules_def if core_rules_def != null else DEFAULT_SKILL_CORE_RULES_RESOURCE

func get_available_disassembly_items(body_inventory_state) -> Array[Resource]:
	var available_items: Array[Resource] = []
	if body_inventory_state == null:
		return available_items
	for stored_item: Resource in body_inventory_state.call("get_disassemblable_items"):
		if not can_preview_disassembly_for_item(stored_item):
			continue
		available_items.append(stored_item.duplicate(true))
	return available_items

func can_preview_disassembly_for_item(stored_item: Resource) -> bool:
	if stored_item == null or not stored_item.has_method("is_raw_drop_item") or not stored_item.is_disassemblable:
		return false
	if stored_item.is_raw_drop_item():
		return _resolve_raw_drop_material_stack(stored_item) != null
	return false

func build_salvage_preview_from_inventory(
		body_inventory_state,
		selected_item_ids: Array
	):
	var selected_items: Array[Resource] = []
	var seen_item_ids: Dictionary = {}
	if body_inventory_state == null:
		return _build_blocked_result(
			&"missing_body_inventory_state",
			"Body inventory state is required to build a disassembly preview."
		)
	for item_instance_id: StringName in selected_item_ids:
		if item_instance_id == StringName() or seen_item_ids.has(item_instance_id):
			continue
		seen_item_ids[item_instance_id] = true
		var stored_item = body_inventory_state.call("get_item", item_instance_id)
		if stored_item == null:
			var missing_item_result = SalvageResultScript.new()
			missing_item_result.failure_reason = &"selected_item_missing"
			missing_item_result.blocking_lines.append("A selected item is no longer present in body inventory.")
			missing_item_result.unsupported_item_ids.append(item_instance_id)
			return missing_item_result
		selected_items.append(stored_item.duplicate(true))
	return build_salvage_preview(selected_items)

func build_salvage_preview(selected_items: Array[Resource]):
	var salvage_result = SalvageResultScript.new()
	var preview_lookup: Dictionary = {}
	var seen_item_ids: Dictionary = {}

	if selected_items.is_empty():
		salvage_result.failure_reason = &"empty_selection"
		salvage_result.blocking_lines.append("Select at least one disassemblable item to preview the output.")
		return salvage_result

	for stored_item: Resource in selected_items:
		if stored_item == null:
			salvage_result.failure_reason = &"invalid_selection_entry"
			salvage_result.blocking_lines.append("One selected disassembly entry is invalid.")
			continue
		if stored_item.item_instance_id == StringName() or seen_item_ids.has(stored_item.item_instance_id):
			continue
		seen_item_ids[stored_item.item_instance_id] = true

		if not stored_item.is_disassemblable:
			salvage_result.failure_reason = &"selection_contains_nondisassemblable_item"
			salvage_result.blocking_lines.append("%s cannot be disassembled." % stored_item.get_resolved_display_name())
			salvage_result.unsupported_item_ids.append(stored_item.item_instance_id)
			continue

		if stored_item.stack_count <= 0:
			salvage_result.failure_reason = &"selection_contains_empty_stack"
			salvage_result.blocking_lines.append("%s has no quantity left to process." % stored_item.get_resolved_display_name())
			salvage_result.unsupported_item_ids.append(stored_item.item_instance_id)
			continue

		var preview_stack: ForgeMaterialStack = _resolve_raw_drop_material_stack(stored_item)
		if preview_stack == null:
			salvage_result.unsupported_item_ids.append(stored_item.item_instance_id)
			salvage_result.blocking_lines.append(_build_unsupported_item_message(stored_item))
			continue

		salvage_result.selected_item_snapshots.append(stored_item.duplicate(true))
		salvage_result.supported_item_ids.append(stored_item.item_instance_id)
		_merge_material_stack(preview_lookup, preview_stack)

	if salvage_result.supported_item_ids.is_empty():
		if salvage_result.failure_reason == StringName():
			salvage_result.failure_reason = &"no_supported_disassembly_items"
		return salvage_result

	salvage_result.preview_material_stacks = _build_sorted_material_stacks(preview_lookup)
	salvage_result.info_lines.append("Disassembly preview is informational only until irreversible confirmation is granted.")
	salvage_result.info_lines.append("Confirmed outputs route directly into forge material storage and do not remain in body inventory.")
	salvage_result.info_lines.append("Blueprint extraction and chase-skill recovery stay disabled until finalized-item makeup data exists.")
	salvage_result.preview_valid = salvage_result.blocking_lines.is_empty() and salvage_result.has_preview_materials()
	return salvage_result

func commit_salvage_preview(
		body_inventory_state,
		material_inventory_state,
		preview_result: Resource,
		irreversible_confirmed: bool = false
	):
	var commit_result = SalvageResultScript.new()
	if preview_result != null:
		commit_result = preview_result.duplicate(true)
	if commit_result == null:
		commit_result = SalvageResultScript.new()

	if not irreversible_confirmed:
		commit_result.failure_reason = &"irreversible_confirmation_required"
		commit_result.blocking_lines.append("Check the irreversible confirmation before disassembling selected items.")
		return commit_result

	if body_inventory_state == null or material_inventory_state == null:
		commit_result.failure_reason = &"missing_commit_state"
		commit_result.blocking_lines.append("Body inventory and forge material inventory are both required to complete disassembly.")
		return commit_result

	if preview_result == null or not preview_result.preview_valid:
		commit_result.failure_reason = &"preview_invalid"
		commit_result.blocking_lines.append("Build a valid disassembly preview before committing outputs.")
		return commit_result

	var revalidated_preview = build_salvage_preview(preview_result.selected_item_snapshots)
	if not revalidated_preview.preview_valid:
		commit_result.failure_reason = &"preview_revalidation_failed"
		for blocking_line: String in revalidated_preview.blocking_lines:
			commit_result.blocking_lines.append(blocking_line)
		return commit_result

	for snapshot_item: Resource in preview_result.selected_item_snapshots:
		if snapshot_item == null:
			commit_result.failure_reason = &"selection_snapshot_invalid"
			commit_result.blocking_lines.append("A selected item snapshot is invalid and cannot be committed safely.")
			return commit_result
		var current_item = body_inventory_state.call("get_item", snapshot_item.item_instance_id)
		if current_item == null:
			commit_result.failure_reason = &"selection_stale"
			commit_result.blocking_lines.append("%s is no longer present in body inventory." % snapshot_item.get_resolved_display_name())
			return commit_result
		if not current_item.matches_exact_state(snapshot_item):
			commit_result.failure_reason = &"selection_stale"
			commit_result.blocking_lines.append("%s changed after the preview was built. Refresh the preview before committing." % snapshot_item.get_resolved_display_name())
			return commit_result

	var taken_items: Array[Resource] = []
	for snapshot_item: Resource in preview_result.selected_item_snapshots:
		var taken_item = body_inventory_state.call("take_item", snapshot_item.item_instance_id, snapshot_item.stack_count)
		if taken_item == null or not taken_item.matches_exact_state(snapshot_item):
			for rollback_item: Resource in taken_items:
				body_inventory_state.call("add_item", rollback_item)
			commit_result.failure_reason = &"take_item_failed"
			commit_result.blocking_lines.append("Failed to remove selected items from body inventory safely.")
			return commit_result
		taken_items.append(taken_item)

	if not inventory_storage_service.route_material_stacks_to_forge_inventory(
		material_inventory_state,
		revalidated_preview.preview_material_stacks
	):
		for rollback_item: Resource in taken_items:
			body_inventory_state.call("add_item", rollback_item)
		commit_result.failure_reason = &"route_to_forge_inventory_failed"
		commit_result.blocking_lines.append("Failed to route processed materials into forge storage.")
		return commit_result

	commit_result.preview_material_stacks = _duplicate_material_stacks(revalidated_preview.preview_material_stacks)
	commit_result.committed_item_ids = preview_result.supported_item_ids.duplicate()
	commit_result.commit_applied = true
	commit_result.failure_reason = StringName()
	commit_result.info_lines.append("Disassembly committed. Processed outputs were routed directly into forge material storage.")
	return commit_result

func _resolve_raw_drop_material_stack(stored_item: Resource) -> ForgeMaterialStack:
	if stored_item == null or not stored_item.is_raw_drop_item():
		return null
	var raw_drop_lookup: Dictionary = material_pipeline_service.build_raw_drop_lookup()
	var raw_drop: RawDropDef = raw_drop_lookup.get(stored_item.raw_drop_id) as RawDropDef
	if raw_drop == null:
		return null
	var process_rule: ProcessRuleDef = material_pipeline_service.find_process_rule_for_drop(raw_drop.drop_id)
	if process_rule == null:
		return null
	var base_material: BaseMaterialDef = material_pipeline_service.find_base_material_by_id(raw_drop.base_material_id)
	if base_material == null:
		return null
	var resolved_pipeline: Dictionary = material_pipeline_service.resolve_pipeline_for_material(
		base_material,
		material_pipeline_service.find_tier_by_id(raw_drop.default_tier_id)
	)
	var material_stack: ForgeMaterialStack = resolved_pipeline.get("material_stack") as ForgeMaterialStack
	if material_stack == null:
		return null
	var preview_stack: ForgeMaterialStack = material_stack.duplicate(true) as ForgeMaterialStack
	preview_stack.quantity *= maxi(stored_item.stack_count, 1)
	return preview_stack

func _merge_material_stack(material_lookup: Dictionary, material_stack: ForgeMaterialStack) -> void:
	if material_stack == null or material_stack.material_variant_id == StringName() or material_stack.quantity <= 0:
		return
	var existing_stack: ForgeMaterialStack = material_lookup.get(material_stack.material_variant_id) as ForgeMaterialStack
	if existing_stack == null:
		material_lookup[material_stack.material_variant_id] = material_stack.duplicate(true)
		return
	existing_stack.quantity += material_stack.quantity

func _build_sorted_material_stacks(material_lookup: Dictionary) -> Array[ForgeMaterialStack]:
	var material_ids: Array = material_lookup.keys()
	material_ids.sort()
	var material_stacks: Array[ForgeMaterialStack] = []
	for material_variant_id in material_ids:
		var material_stack: ForgeMaterialStack = material_lookup.get(material_variant_id) as ForgeMaterialStack
		if material_stack == null:
			continue
		material_stacks.append(material_stack)
	return material_stacks

func _duplicate_material_stacks(material_stacks: Array[ForgeMaterialStack]) -> Array[ForgeMaterialStack]:
	var duplicated_stacks: Array[ForgeMaterialStack] = []
	for material_stack: ForgeMaterialStack in material_stacks:
		if material_stack == null:
			continue
		duplicated_stacks.append(material_stack.duplicate(true) as ForgeMaterialStack)
	return duplicated_stacks

func _build_unsupported_item_message(stored_item: Resource) -> String:
	if stored_item == null:
		return "One selected item cannot be disassembled yet."
	if stored_item.is_finalized_item():
		return "%s cannot be salvaged yet because finalized-item material makeup has not been implemented." % stored_item.get_resolved_display_name()
	if stored_item.is_raw_drop_item():
		return "%s cannot be processed because its raw-drop pipeline is incomplete." % stored_item.get_resolved_display_name()
	return "%s does not have a supported disassembly path yet." % stored_item.get_resolved_display_name()

func _build_blocked_result(reason_id: StringName, message: String):
	var salvage_result = SalvageResultScript.new()
	salvage_result.failure_reason = reason_id
	salvage_result.blocking_lines.append(message)
	return salvage_result
