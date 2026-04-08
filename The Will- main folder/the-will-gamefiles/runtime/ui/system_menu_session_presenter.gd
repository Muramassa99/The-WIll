extends RefCounted
class_name SystemMenuSessionPresenter

const UserSettingsStateScript = preload("res://core/models/user_settings_state.gd")

func configure(player, state, footer_status_label: Label, footer_status_default: String) -> Dictionary:
	if footer_status_label != null:
		footer_status_label.text = footer_status_default
	return {
		"active_player": player,
		"settings_state": state as UserSettingsState if state != null else UserSettingsStateScript.load_or_create(),
	}

func is_open(panel: Control) -> bool:
	return panel != null and panel.visible

func open_menu(active_player, backdrop: CanvasItem, panel: Control) -> void:
	if panel == null or backdrop == null:
		return
	backdrop.visible = true
	panel.visible = true
	if active_player != null and active_player.has_method("set_ui_mode_enabled"):
		active_player.call("set_ui_mode_enabled", true)

func close_menu(active_player, backdrop: CanvasItem, panel: Control) -> void:
	if panel == null or backdrop == null:
		return
	backdrop.visible = false
	panel.visible = false
	if active_player != null and active_player.has_method("set_ui_mode_enabled"):
		active_player.call("set_ui_mode_enabled", false)
