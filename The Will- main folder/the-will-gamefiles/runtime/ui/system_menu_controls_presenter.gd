extends RefCounted
class_name SystemMenuControlsPresenter

const UserSettingsRuntimeScript = preload("res://runtime/system/user_settings_runtime.gd")

func refresh_bindings_list(
	settings_state: UserSettingsState,
	selected_controls_category: String,
	bindings_container: VBoxContainer,
	bindings_status_label: Label,
	begin_rebind_callable: Callable
) -> void:
	for child: Node in bindings_container.get_children():
		child.queue_free()
	if selected_controls_category.is_empty():
		bindings_status_label.text = "No input category selected."
		return
	bindings_status_label.text = "Pick a binding and press a new key. Escape cancels the rebind prompt."
	for action_name: StringName in UserSettingsRuntimeScript.get_actions_for_category(selected_controls_category):
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var action_label: Label = Label.new()
		action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_label.text = UserSettingsRuntimeScript.get_action_display_name(action_name)
		row.add_child(action_label)

		var binding_button: Button = Button.new()
		binding_button.custom_minimum_size = Vector2(180.0, 0.0)
		binding_button.text = UserSettingsRuntimeScript.get_keybinding_label(settings_state.get_keybinding_data(action_name, UserSettingsRuntimeScript.get_default_binding_data(action_name)))
		binding_button.pressed.connect(begin_rebind_callable.bind(action_name))
		row.add_child(binding_button)

		bindings_container.add_child(row)

func begin_rebind(action_name: StringName, bindings_status_label: Label, footer_status_label: Label) -> StringName:
	var action_display_name: String = UserSettingsRuntimeScript.get_action_display_name(action_name)
	bindings_status_label.text = "Press a new key for %s." % action_display_name
	footer_status_label.text = "Listening for a new key on %s. Escape cancels." % action_display_name
	return action_name

func commit_key_rebind(settings_state: UserSettingsState, action_name: StringName, key_event: InputEventKey) -> Dictionary:
	settings_state.set_keybinding_event(action_name, key_event)
	var action_display_name: String = UserSettingsRuntimeScript.get_action_display_name(action_name)
	return {
		"status_message": "Saved controls for %s." % action_display_name,
		"bindings_status_text": "%s is now bound to %s." % [
			action_display_name,
			UserSettingsRuntimeScript.get_keybinding_label(settings_state.get_keybinding_data(action_name))
		],
	}

func restore_selected_category_defaults(settings_state: UserSettingsState, selected_controls_category: String) -> Dictionary:
	if selected_controls_category.is_empty():
		return {
			"status_message": "",
			"bindings_status_text": "",
		}
	settings_state.reset_keybindings_for_actions(UserSettingsRuntimeScript.get_actions_for_category(selected_controls_category))
	var category_display_name: String = UserSettingsRuntimeScript.get_category_display_name(selected_controls_category)
	var status_text: String = "%s bindings restored to defaults." % category_display_name
	return {
		"status_message": status_text,
		"bindings_status_text": status_text,
	}

func find_category_index(category_name: String) -> int:
	var categories: Array[String] = UserSettingsRuntimeScript.get_categories()
	for index in range(categories.size()):
		if categories[index] == category_name:
			return index
	return 0
