extends RefCounted
class_name SystemMenuStateFlowPresenter

const UserSettingsRuntimeScript = preload("res://runtime/system/user_settings_runtime.gd")

func refresh_from_state(
	settings_state: UserSettingsState,
	selected_controls_category: String,
	settings_presenter: SystemMenuSettingsPresenter,
	controls_presenter: SystemMenuControlsPresenter,
	option_payload: Dictionary,
	controls_payload: Dictionary,
	resolution_options: Array,
	max_fps_options: Array
) -> Dictionary:
	if settings_state == null:
		return {
			"selected_controls_category": selected_controls_category,
			"refreshed": false,
		}
	var resolved_controls_category: String = settings_presenter.refresh_from_state(
		settings_state,
		selected_controls_category,
		option_payload.get("window_mode_option", null),
		option_payload.get("monitor_option", null),
		option_payload.get("resolution_option", null),
		option_payload.get("vsync_check_box", null),
		option_payload.get("render_scale_option", null),
		option_payload.get("max_fps_option", null),
		option_payload.get("master_volume_slider", null),
		option_payload.get("master_volume_value_label", null),
		option_payload.get("master_mute_check_box", null),
		option_payload.get("ui_scale_option", null),
		option_payload.get("text_scale_option", null),
		option_payload.get("controls_category_option", null),
		resolution_options,
		max_fps_options
	)
	controls_presenter.refresh_bindings_list(
		settings_state,
		resolved_controls_category,
		controls_payload.get("bindings_container", null),
		controls_payload.get("bindings_status_label", null),
		controls_payload.get("begin_rebind_callable", Callable())
	)
	return {
		"selected_controls_category": resolved_controls_category,
		"refreshed": true,
	}

func begin_rebind(
	action_name: StringName,
	controls_presenter: SystemMenuControlsPresenter,
	bindings_status_label: Label,
	footer_status_label: Label
) -> StringName:
	return controls_presenter.begin_rebind(action_name, bindings_status_label, footer_status_label)

func commit_key_rebind(
	settings_state: UserSettingsState,
	action_name: StringName,
	key_event: InputEventKey,
	controls_presenter: SystemMenuControlsPresenter,
	controls_payload: Dictionary
) -> Dictionary:
	var commit_result: Dictionary = controls_presenter.commit_key_rebind(settings_state, action_name, key_event)
	_apply_bindings_status_text(
		String(commit_result.get("bindings_status_text", "")),
		controls_payload.get("bindings_status_label", null)
	)
	controls_presenter.refresh_bindings_list(
		settings_state,
		String(controls_payload.get("selected_controls_category", "")),
		controls_payload.get("bindings_container", null),
		controls_payload.get("bindings_status_label", null),
		controls_payload.get("begin_rebind_callable", Callable())
	)
	return commit_result

func apply_and_persist_settings(
	settings_state: UserSettingsState,
	root: Window,
	footer_status_label: Label,
	status_message: String = ""
) -> void:
	if settings_state == null:
		return
	UserSettingsRuntimeScript.ensure_input_actions(settings_state)
	UserSettingsRuntimeScript.apply_settings(settings_state, root)
	var persisted_ok: bool = settings_state.persist()
	if not status_message.is_empty():
		footer_status_label.text = status_message if persisted_ok else "%s Saving failed." % status_message
		return
	if not persisted_ok:
		footer_status_label.text = "Settings could not be saved."

func handle_controls_category_selected(
	is_refreshing_ui: bool,
	index: int,
	controls_presenter: SystemMenuControlsPresenter,
	settings_state: UserSettingsState,
	controls_payload: Dictionary
) -> Dictionary:
	if is_refreshing_ui:
		return {"changed": false}
	var categories: Array[String] = UserSettingsRuntimeScript.get_categories()
	if index < 0 or index >= categories.size():
		return {"changed": false}
	var selected_controls_category: String = categories[index]
	controls_presenter.refresh_bindings_list(
		settings_state,
		selected_controls_category,
		controls_payload.get("bindings_container", null),
		controls_payload.get("bindings_status_label", null),
		controls_payload.get("begin_rebind_callable", Callable())
	)
	return {
		"changed": true,
		"selected_controls_category": selected_controls_category,
	}

func restore_selected_category_defaults(
	settings_state: UserSettingsState,
	selected_controls_category: String,
	controls_presenter: SystemMenuControlsPresenter,
	controls_payload: Dictionary
) -> Dictionary:
	var restore_result: Dictionary = controls_presenter.restore_selected_category_defaults(settings_state, selected_controls_category)
	var status_message: String = String(restore_result.get("status_message", ""))
	if status_message.is_empty():
		return {"restored": false}
	_apply_bindings_status_text(
		String(restore_result.get("bindings_status_text", status_message)),
		controls_payload.get("bindings_status_label", null)
	)
	controls_presenter.refresh_bindings_list(
		settings_state,
		selected_controls_category,
		controls_payload.get("bindings_container", null),
		controls_payload.get("bindings_status_label", null),
		controls_payload.get("begin_rebind_callable", Callable())
	)
	return {
		"restored": true,
		"status_message": status_message,
	}

func reset_active_page_to_defaults(
	current_page: StringName,
	settings_state: UserSettingsState,
	selected_controls_category: String,
	controls_presenter: SystemMenuControlsPresenter,
	controls_payload: Dictionary
) -> Dictionary:
	if settings_state == null:
		return {
			"handled": false,
			"apply_and_refresh": false,
			"status_message": "",
		}
	match current_page:
		&"settings":
			settings_state.reset_display_to_defaults()
			settings_state.reset_audio_to_defaults()
			return {
				"handled": true,
				"apply_and_refresh": true,
				"status_message": "Display and audio settings restored to defaults.",
			}
		&"interface":
			settings_state.reset_interface_to_defaults()
			return {
				"handled": true,
				"apply_and_refresh": true,
				"status_message": "Interface scale restored to defaults.",
			}
		&"controls":
			var restore_result: Dictionary = restore_selected_category_defaults(
				settings_state,
				selected_controls_category,
				controls_presenter,
				controls_payload
			)
			return {
				"handled": true,
				"apply_and_refresh": bool(restore_result.get("restored", false)),
				"status_message": String(restore_result.get("status_message", "")),
			}
		_:
			return {
				"handled": true,
				"apply_and_refresh": false,
				"status_message": "This page does not have resettable live settings yet.",
			}

func _apply_bindings_status_text(status_text: String, bindings_status_label: Label) -> void:
	if bindings_status_label != null:
		bindings_status_label.text = status_text
