extends RefCounted
class_name ForgeBenchDebugPresenter

func open_debug_popup(
	panel_visible: bool,
	flush_pending_edit_refresh: Callable,
	debug_status_dirty: bool,
	status_text_value: String,
	refresh_status_text: Callable,
	last_layout_compact_mode: bool,
	compact_debug_popup_min_size: Vector2i,
	wide_debug_popup_min_size: Vector2i,
	debug_popup: PopupPanel
) -> void:
	if not panel_visible:
		return
	flush_pending_edit_refresh.call(true)
	if debug_status_dirty or status_text_value.strip_edges().is_empty():
		refresh_status_text.call()
	var popup_size: Vector2i = compact_debug_popup_min_size if last_layout_compact_mode else wide_debug_popup_min_size
	debug_popup.popup_centered(popup_size)

func handle_active_wip_changed(
	panel_visible: bool,
	suppress_active_wip_refresh: bool,
	refresh_all: Callable
) -> void:
	if not panel_visible or suppress_active_wip_refresh:
		return
	refresh_all.call()

func handle_active_test_print_changed(
	panel_visible: bool,
	debug_popup_visible: bool,
	refresh_status_text: Callable
) -> bool:
	if not panel_visible:
		return false
	if debug_popup_visible:
		refresh_status_text.call()
	return true
