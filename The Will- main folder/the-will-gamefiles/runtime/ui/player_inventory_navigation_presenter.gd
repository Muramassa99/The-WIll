extends RefCounted
class_name PlayerInventoryNavigationPresenter

func resolve_page_state(
	requested_page_id: StringName,
	default_page_id: StringName,
	page_order: Array[StringName]
) -> Dictionary:
	var resolved_page_id: StringName = requested_page_id if requested_page_id != StringName() else default_page_id
	var resolved_page_index: int = page_order.find(resolved_page_id)
	if resolved_page_index == -1:
		resolved_page_id = default_page_id
		resolved_page_index = page_order.find(default_page_id)
	if resolved_page_index == -1:
		resolved_page_index = 0
	return {
		"active_page_id": resolved_page_id,
		"page_index": resolved_page_index,
	}
