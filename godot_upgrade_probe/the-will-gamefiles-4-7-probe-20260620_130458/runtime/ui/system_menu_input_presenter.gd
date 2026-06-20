extends RefCounted
class_name SystemMenuInputPresenter

func handle_unhandled_input(
	panel_visible: bool,
	pending_rebind_action: StringName,
	event: InputEvent,
	settings_page_id: StringName,
	social_page_id: StringName
) -> Dictionary:
	if not panel_visible:
		return {"handled": false}
	if pending_rebind_action != StringName() and event is InputEventKey:
		var pending_key_event: InputEventKey = event
		if pending_key_event.pressed and not pending_key_event.echo:
			if pending_key_event.keycode == KEY_ESCAPE:
				return {
					"handled": true,
					"cancel_rebind": true,
					"bindings_status_text": "Rebind cancelled.",
				}
			return {
				"handled": true,
				"commit_rebind": true,
				"action_name": pending_rebind_action,
				"key_event": pending_key_event,
			}
	if event.is_action_pressed(&"ui_settings"):
		return {"handled": true, "open_page": settings_page_id}
	if event.is_action_pressed(&"ui_social"):
		return {"handled": true, "open_page": social_page_id}
	if event.is_action_pressed(&"menu_toggle"):
		return {"handled": true, "close_menu": true}
	return {"handled": false}
