extends RefCounted
class_name DisassemblyBenchWorkflowPresenter

var selected_item_ids: Array[StringName] = []
var current_preview_result
var material_lookup: Dictionary = {}

func reset_runtime_state() -> void:
	selected_item_ids.clear()
	current_preview_result = null

func refresh_material_lookup(text_presenter, material_pipeline_service) -> void:
	material_lookup = text_presenter.refresh_material_lookup(material_pipeline_service)

func refresh_all(
	body_inventory_state,
	salvage_service,
	text_presenter,
	ui_nodes: Dictionary,
	footer_message: String = ""
) -> void:
	_prune_stale_selection(body_inventory_state)
	_refresh_inventory_list(body_inventory_state, salvage_service, text_presenter, ui_nodes)
	_refresh_selected_list(body_inventory_state, text_presenter, ui_nodes)
	_refresh_preview_state(body_inventory_state, salvage_service, text_presenter, ui_nodes)
	_refresh_action_state(ui_nodes)
	if not footer_message.is_empty():
		_get_footer_status_label(ui_nodes).text = footer_message

func handle_inventory_item_clicked(
	index: int,
	body_inventory_state,
	salvage_service,
	text_presenter,
	ui_nodes: Dictionary
) -> void:
	var inventory_list: ItemList = _get_inventory_list(ui_nodes)
	if index < 0 or index >= inventory_list.item_count:
		return
	var item_instance_id = inventory_list.get_item_metadata(index)
	if item_instance_id == null:
		return
	var resolved_item_id: StringName = item_instance_id
	if resolved_item_id == StringName() or selected_item_ids.has(resolved_item_id):
		return
	selected_item_ids.append(resolved_item_id)
	_get_irreversible_check_box(ui_nodes).button_pressed = false
	refresh_all(
		body_inventory_state,
		salvage_service,
		text_presenter,
		ui_nodes,
		"Item moved into the disassembly queue."
	)

func handle_selected_item_clicked(
	index: int,
	body_inventory_state,
	salvage_service,
	text_presenter,
	ui_nodes: Dictionary
) -> void:
	var selected_list: ItemList = _get_selected_list(ui_nodes)
	if index < 0 or index >= selected_list.item_count:
		return
	var item_instance_id = selected_list.get_item_metadata(index)
	if item_instance_id == null:
		return
	var resolved_item_id: StringName = item_instance_id
	selected_item_ids.erase(resolved_item_id)
	_get_irreversible_check_box(ui_nodes).button_pressed = false
	refresh_all(
		body_inventory_state,
		salvage_service,
		text_presenter,
		ui_nodes,
		"Item returned to body inventory and removed from the disassembly queue."
	)

func handle_irreversible_toggled(ui_nodes: Dictionary) -> void:
	_refresh_action_state(ui_nodes)
	if _get_irreversible_check_box(ui_nodes).button_pressed:
		_get_footer_status_label(ui_nodes).text = "Irreversible confirmation granted for the current preview."
	else:
		_get_footer_status_label(ui_nodes).text = "Disassembly remains blocked until the irreversible confirmation is checked."

func handle_clear_selection_pressed(
	body_inventory_state,
	salvage_service,
	text_presenter,
	ui_nodes: Dictionary
) -> void:
	selected_item_ids.clear()
	_get_irreversible_check_box(ui_nodes).button_pressed = false
	refresh_all(body_inventory_state, salvage_service, text_presenter, ui_nodes, "Disassembly selection cleared.")

func handle_disassemble_pressed(
	body_inventory_state,
	forge_inventory_state,
	salvage_service,
	text_presenter,
	ui_nodes: Dictionary
) -> void:
	var commit_result = salvage_service.call(
		"commit_salvage_preview",
		body_inventory_state,
		forge_inventory_state,
		current_preview_result,
		_get_irreversible_check_box(ui_nodes).button_pressed
	)
	if commit_result != null and bool(commit_result.commit_applied):
		var routed_quantity: int = int(commit_result.call("get_total_preview_quantity"))
		selected_item_ids.clear()
		_get_irreversible_check_box(ui_nodes).button_pressed = false
		refresh_all(
			body_inventory_state,
			salvage_service,
			text_presenter,
			ui_nodes,
			"Disassembly committed. %d processed forge materials were routed into forge storage." % routed_quantity
		)
		return
	var failure_lines: PackedStringArray = []
	if commit_result != null and not commit_result.blocking_lines.is_empty():
		failure_lines = commit_result.blocking_lines
	var failure_text: String = "\n".join(failure_lines) if not failure_lines.is_empty() else "Disassembly could not be completed."
	refresh_all(body_inventory_state, salvage_service, text_presenter, ui_nodes, failure_text)

func _refresh_inventory_list(
	body_inventory_state,
	salvage_service,
	text_presenter,
	ui_nodes: Dictionary
) -> void:
	var inventory_list: ItemList = _get_inventory_list(ui_nodes)
	inventory_list.clear()
	var available_items: Array[Resource] = salvage_service.call("get_available_disassembly_items", body_inventory_state)
	for stored_item: Resource in available_items:
		if stored_item == null:
			continue
		if selected_item_ids.has(stored_item.item_instance_id):
			continue
		var item_index: int = inventory_list.add_item(text_presenter.format_stored_item_label(stored_item))
		inventory_list.set_item_metadata(item_index, stored_item.item_instance_id)
	if inventory_list.item_count == 0:
		inventory_list.add_item("No supported disassembly items in body inventory.")
		inventory_list.set_item_disabled(0, true)

func _refresh_selected_list(body_inventory_state, text_presenter, ui_nodes: Dictionary) -> void:
	var selected_list: ItemList = _get_selected_list(ui_nodes)
	selected_list.clear()
	for item_instance_id: StringName in selected_item_ids:
		var stored_item = body_inventory_state.call("get_item", item_instance_id) if body_inventory_state != null else null
		if stored_item == null:
			continue
		var item_index: int = selected_list.add_item(text_presenter.format_stored_item_label(stored_item))
		selected_list.set_item_metadata(item_index, item_instance_id)
	if selected_list.item_count == 0:
		selected_list.add_item("Nothing is currently queued for disassembly.")
		selected_list.set_item_disabled(0, true)

func _refresh_preview_state(
	body_inventory_state,
	salvage_service,
	text_presenter,
	ui_nodes: Dictionary
) -> void:
	var output_preview_list: ItemList = _get_output_preview_list(ui_nodes)
	var output_status_label: Label = _get_output_status_label(ui_nodes)
	var warning_text_label: Label = _get_warning_text_label(ui_nodes)
	var summary_label: Label = _get_summary_label(ui_nodes)
	var extract_blueprint_button: Button = _get_extract_blueprint_button(ui_nodes)
	var select_skill_button: Button = _get_select_skill_button(ui_nodes)
	var optional_status_label: Label = _get_optional_status_label(ui_nodes)

	output_preview_list.clear()
	current_preview_result = salvage_service.call("build_salvage_preview_from_inventory", body_inventory_state, selected_item_ids)
	var selected_stack_total: int = text_presenter.get_selected_stack_total(selected_item_ids, body_inventory_state)
	var preview_total: int = 0

	if current_preview_result != null and current_preview_result.preview_valid:
		for material_stack: ForgeMaterialStack in current_preview_result.preview_material_stacks:
			if material_stack == null:
				continue
			preview_total += material_stack.quantity
			output_preview_list.add_item(text_presenter.format_material_stack_label(material_stack, material_lookup))
		output_status_label.text = "Preview only. These processed materials do not exist yet and will only route into forge storage after confirmation."
	else:
		output_preview_list.add_item("No processed output preview yet.")
		output_preview_list.set_item_disabled(0, true)
		if current_preview_result != null and not current_preview_result.blocking_lines.is_empty():
			output_status_label.text = "\n".join(current_preview_result.blocking_lines)
		else:
			output_status_label.text = "Select items from the left list to preview the processed material output."

	var warning_lines: PackedStringArray = []
	warning_lines.append("Disassembly converts selected items into forge building materials.")
	warning_lines.append("The resulting materials are routed directly into forge storage and become non-tradable in this first slice.")
	warning_lines.append("This change is permanent and cannot be reverted.")
	warning_text_label.text = "\n".join(warning_lines)

	summary_label.text = "Selected item rows: %d\nSelected item quantity: %d\nProjected forge materials: %d" % [
		selected_item_ids.size(),
		selected_stack_total,
		preview_total,
	]

	var can_extract_blueprint: bool = current_preview_result != null and bool(current_preview_result.can_extract_blueprint)
	var can_select_skill: bool = current_preview_result != null and bool(current_preview_result.can_select_skill)
	extract_blueprint_button.visible = can_extract_blueprint
	select_skill_button.visible = can_select_skill
	extract_blueprint_button.disabled = not can_extract_blueprint
	select_skill_button.disabled = not can_select_skill
	optional_status_label.visible = not can_extract_blueprint and not can_select_skill
	optional_status_label.text = "No blueprint or chase-skill extraction options are available for the current selection."

func _refresh_action_state(ui_nodes: Dictionary) -> void:
	var preview_valid: bool = current_preview_result != null and bool(current_preview_result.preview_valid)
	_get_disassemble_button(ui_nodes).disabled = not preview_valid or not _get_irreversible_check_box(ui_nodes).button_pressed
	_get_clear_selection_button(ui_nodes).disabled = selected_item_ids.is_empty()

func _prune_stale_selection(body_inventory_state) -> void:
	var valid_ids: Array[StringName] = []
	for item_instance_id: StringName in selected_item_ids:
		var stored_item = body_inventory_state.call("get_item", item_instance_id) if body_inventory_state != null else null
		if stored_item == null:
			continue
		valid_ids.append(item_instance_id)
	selected_item_ids = valid_ids

func _get_inventory_list(ui_nodes: Dictionary) -> ItemList:
	return ui_nodes.get("inventory_list") as ItemList

func _get_output_preview_list(ui_nodes: Dictionary) -> ItemList:
	return ui_nodes.get("output_preview_list") as ItemList

func _get_warning_text_label(ui_nodes: Dictionary) -> Label:
	return ui_nodes.get("warning_text_label") as Label

func _get_irreversible_check_box(ui_nodes: Dictionary) -> CheckBox:
	return ui_nodes.get("irreversible_check_box") as CheckBox

func _get_disassemble_button(ui_nodes: Dictionary) -> Button:
	return ui_nodes.get("disassemble_button") as Button

func _get_clear_selection_button(ui_nodes: Dictionary) -> Button:
	return ui_nodes.get("clear_selection_button") as Button

func _get_output_status_label(ui_nodes: Dictionary) -> Label:
	return ui_nodes.get("output_status_label") as Label

func _get_selected_list(ui_nodes: Dictionary) -> ItemList:
	return ui_nodes.get("selected_list") as ItemList

func _get_summary_label(ui_nodes: Dictionary) -> Label:
	return ui_nodes.get("summary_label") as Label

func _get_optional_status_label(ui_nodes: Dictionary) -> Label:
	return ui_nodes.get("optional_status_label") as Label

func _get_extract_blueprint_button(ui_nodes: Dictionary) -> Button:
	return ui_nodes.get("extract_blueprint_button") as Button

func _get_select_skill_button(ui_nodes: Dictionary) -> Button:
	return ui_nodes.get("select_skill_button") as Button

func _get_footer_status_label(ui_nodes: Dictionary) -> Label:
	return ui_nodes.get("footer_status_label") as Label
