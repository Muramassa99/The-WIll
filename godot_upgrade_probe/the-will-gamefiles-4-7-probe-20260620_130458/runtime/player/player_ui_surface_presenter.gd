extends RefCounted
class_name PlayerUiSurfacePresenter

func toggle_system_menu(system_menu_overlay: CanvasLayer) -> void:
	if system_menu_overlay == null:
		return
	system_menu_overlay.toggle_menu()

func open_system_menu_page(system_menu_overlay: CanvasLayer, page_id: StringName) -> void:
	if system_menu_overlay == null:
		return
	if system_menu_overlay.has_method("open_page"):
		system_menu_overlay.call("open_page", page_id)
	else:
		system_menu_overlay.call("toggle_menu")

func toggle_player_inventory_page(
	player_inventory_overlay: CanvasLayer,
	active_player,
	page_id: StringName,
	source_label: String
) -> void:
	if player_inventory_overlay == null:
		return
	if player_inventory_overlay.has_method("toggle_page_for"):
		player_inventory_overlay.call("toggle_page_for", active_player, page_id, source_label)
	else:
		player_inventory_overlay.call("open_page_for", active_player, page_id, source_label)

func open_player_inventory_page(
	player_inventory_overlay: CanvasLayer,
	active_player,
	page_id: StringName,
	source_label: String
) -> void:
	if player_inventory_overlay != null and player_inventory_overlay.has_method("open_page_for"):
		player_inventory_overlay.call("open_page_for", active_player, page_id, source_label)

func set_mouse_mode_for_ui(enabled: bool) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if enabled else Input.MOUSE_MODE_CAPTURED)

func sync_crosshair_visibility(crosshair_overlay: Control, ui_mode_enabled: bool) -> void:
	if crosshair_overlay == null:
		return
	crosshair_overlay.set_crosshair_visible_state(
		not ui_mode_enabled and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	)
