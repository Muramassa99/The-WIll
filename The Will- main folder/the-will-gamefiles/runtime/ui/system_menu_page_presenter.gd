extends RefCounted
class_name SystemMenuPagePresenter

func apply_page_selection(
	page_id: StringName,
	page_ids: Dictionary,
	settings_page: Control,
	controls_page: Control,
	interface_page: Control,
	social_page: Control,
	help_page: Control,
	page_title_label: Label,
	page_subtitle_label: Label,
	reset_page_button: Button,
	selected_controls_category: String,
	footer_status_label: Label,
	footer_status_default: String
) -> void:
	settings_page.visible = page_id == page_ids.get("settings", StringName())
	controls_page.visible = page_id == page_ids.get("controls", StringName())
	interface_page.visible = page_id == page_ids.get("interface", StringName())
	social_page.visible = page_id == page_ids.get("social", StringName())
	help_page.visible = page_id == page_ids.get("help", StringName())

	if page_id == page_ids.get("controls", StringName()):
		page_title_label.text = "Controls"
		page_subtitle_label.text = "Per-user keybindings grouped by movement, combat, camera, UI/menu, and forge contexts."
	elif page_id == page_ids.get("interface", StringName()):
		page_title_label.text = "Interface"
		page_subtitle_label.text = "Adjust global UI and text scaling while preserving relative size hierarchy."
	elif page_id == page_ids.get("social", StringName()):
		page_title_label.text = "Social"
		page_subtitle_label.text = "Privacy, request filtering, and social-clutter controls will expand here next."
	elif page_id == page_ids.get("help", StringName()):
		page_title_label.text = "Help"
		page_subtitle_label.text = "Use this overlay as a control room for active expeditions. World simulation continues while it is open."
	else:
		page_title_label.text = "Settings"
		page_subtitle_label.text = "Display and audio settings apply immediately and persist per user across boots."

	refresh_page_actions(page_id, page_ids, selected_controls_category, reset_page_button)
	if footer_status_label.text.is_empty() or footer_status_label.text == footer_status_default:
		footer_status_label.text = footer_status_default

func refresh_page_actions(
	current_page: StringName,
	page_ids: Dictionary,
	selected_controls_category: String,
	reset_page_button: Button
) -> void:
	if current_page == page_ids.get("settings", StringName()):
		reset_page_button.disabled = false
		reset_page_button.text = "Reset Display / Audio"
	elif current_page == page_ids.get("controls", StringName()):
		reset_page_button.disabled = selected_controls_category.is_empty()
		reset_page_button.text = "Reset Controls"
	elif current_page == page_ids.get("interface", StringName()):
		reset_page_button.disabled = false
		reset_page_button.text = "Reset Interface"
	else:
		reset_page_button.disabled = true
		reset_page_button.text = "No Reset Available"
