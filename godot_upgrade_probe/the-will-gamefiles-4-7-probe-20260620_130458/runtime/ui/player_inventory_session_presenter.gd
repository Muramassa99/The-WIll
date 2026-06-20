extends RefCounted
class_name PlayerInventorySessionPresenter

func should_close_existing_page(
	is_open: bool,
	active_player,
	active_page_id: StringName,
	requested_player,
	requested_page_id: StringName
) -> bool:
	return is_open and active_player == requested_player and active_page_id == requested_page_id

func open_overlay(
	player,
	page_id: StringName,
	source_label: String,
	panel: Control,
	backdrop: CanvasItem
) -> Dictionary:
	var resolved_source_label: String = source_label.strip_edges() if not source_label.strip_edges().is_empty() else "Player Inventory"
	if player != null and player.has_method("set_ui_mode_enabled"):
		player.call("set_ui_mode_enabled", true)
	panel.visible = true
	backdrop.visible = true
	return {
		"active_player": player,
		"active_page_id": page_id,
		"active_source_label": resolved_source_label,
	}

func close_overlay(active_player, panel: Control, backdrop: CanvasItem) -> Dictionary:
	if not panel.visible:
		return {
			"closed": false,
			"active_player": active_player,
			"active_source_label": "Player Inventory",
		}
	panel.visible = false
	backdrop.visible = false
	if active_player != null and active_player.has_method("set_ui_mode_enabled"):
		active_player.call("set_ui_mode_enabled", false)
	return {
		"closed": true,
		"active_player": null,
		"active_source_label": "Player Inventory",
	}
