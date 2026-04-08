extends RefCounted
class_name PlayerInventoryRefreshPresenter

const DEFAULT_READY_STATUS := "Inventory ready."

func refresh_all(
	page_presenter: PlayerInventoryPagePresenter,
	active_source_label: String,
	active_page_id: StringName,
	footer_status_label: Label,
	status_text: String,
	queue_layout_refresh_callable: Callable,
	payloads: Dictionary
) -> void:
	if page_presenter == null:
		return
	var header_payload: Dictionary = payloads.get("header", {})
	page_presenter.refresh_header_text(
		header_payload.get("title_label", null),
		header_payload.get("subtitle_label", null),
		active_source_label
	)
	page_presenter.refresh_nav_button_state(
		active_page_id,
		payloads.get("page_buttons", {})
	)
	_refresh_equipment_page(page_presenter, payloads.get("equipment", {}))
	_refresh_body_inventory_page(page_presenter, payloads.get("body_inventory", {}))
	_refresh_storage_page(page_presenter, payloads.get("storage", {}))
	_refresh_forge_materials_page(page_presenter, payloads.get("forge_materials", {}))
	_refresh_wip_page(page_presenter, payloads.get("wip_storage", {}))
	_apply_footer_status(footer_status_label, status_text)
	if queue_layout_refresh_callable.is_valid():
		queue_layout_refresh_callable.call()

func _refresh_equipment_page(page_presenter: PlayerInventoryPagePresenter, payload: Dictionary) -> void:
	page_presenter.refresh_equipment_page(
		payload.get("equipment_list", null),
		payload.get("equipment_detail_label", null),
		payload.get("clear_slot_button", null),
		payload.get("equipment_slot_registry", null),
		payload.get("selected_equipment_slot_id", StringName()),
		payload.get("equipment_state", null),
		payload.get("ordered_equipment_slots", []),
		payload.get("format_equipped_entry_label_callable", Callable())
	)

func _refresh_body_inventory_page(page_presenter: PlayerInventoryPagePresenter, payload: Dictionary) -> void:
	page_presenter.refresh_body_inventory_page(
		payload.get("body_inventory_list", null),
		payload.get("body_inventory_detail_label", null),
		payload.get("move_to_storage_button", null),
		payload.get("body_inventory_state", null),
		payload.get("selected_body_item_id", StringName()),
		payload.get("format_stored_item_label_callable", Callable())
	)

func _refresh_storage_page(page_presenter: PlayerInventoryPagePresenter, payload: Dictionary) -> void:
	page_presenter.refresh_storage_page(
		payload.get("storage_list", null),
		payload.get("storage_detail_label", null),
		payload.get("move_to_inventory_button", null),
		payload.get("storage_state", null),
		payload.get("selected_storage_item_id", StringName()),
		payload.get("format_stored_item_label_callable", Callable())
	)

func _refresh_forge_materials_page(page_presenter: PlayerInventoryPagePresenter, payload: Dictionary) -> void:
	page_presenter.refresh_forge_materials_page(
		payload.get("forge_materials_list", null),
		payload.get("forge_materials_summary_label", null),
		payload.get("forge_inventory_state", null),
		payload.get("format_material_stack_label_callable", Callable())
	)

func _refresh_wip_page(page_presenter: PlayerInventoryPagePresenter, payload: Dictionary) -> void:
	page_presenter.refresh_wip_page(
		payload.get("wip_list", null),
		payload.get("wip_detail_label", null),
		payload.get("mark_for_forge_button", null),
		payload.get("equip_right_hand_button", null),
		payload.get("equip_left_hand_button", null),
		payload.get("clear_hand_test_button", null),
		payload.get("wip_library", null),
		payload.get("selected_wip_id", StringName()),
		payload.get("format_wip_label_callable", Callable()),
		payload.get("get_wip_display_name_callable", Callable()),
		payload.get("count_wip_cells_callable", Callable()),
		payload.get("preview_wip_test_status_callable", Callable()),
		payload.get("hands_are_empty_callable", Callable())
	)

func _apply_footer_status(footer_status_label: Label, status_text: String) -> void:
	if footer_status_label == null:
		return
	if not status_text.is_empty():
		footer_status_label.text = status_text
	elif footer_status_label.text.strip_edges().is_empty():
		footer_status_label.text = DEFAULT_READY_STATUS
