extends RefCounted


static func configure_major_workspace(window: Window) -> void:
	if not is_instance_valid(window):
		return
	# A major workspace is a deliberate editing surface, not a dismiss-on-focus
	# popup. It remains transient to its owning application window without
	# blocking uncovered sibling surfaces.
	window.popup_window = false
	window.popup_wm_hint = false
	window.transient = true
	window.transient_to_focused = false
	window.exclusive = false


static func configure_owned_popup(window: Window) -> void:
	if not is_instance_valid(window):
		return
	# Temporary menus, sub-workspaces, and focused dialogs retain normal popup
	# dismissal. Their node/window parent defines the next-of-kin focus target.
	window.popup_window = true
	window.popup_wm_hint = true
	window.transient = true
	window.transient_to_focused = false
	window.exclusive = false


static func attach_owned_popup(
	owner_window: Window,
	child_window: Window
) -> bool:
	if (
		not is_instance_valid(owner_window)
		or not is_instance_valid(child_window)
		or owner_window == child_window
		or child_window.visible
		or child_window.is_ancestor_of(owner_window)
	):
		return false
	configure_owned_popup(child_window)
	if _find_nearest_parent_window(child_window) == owner_window:
		return true
	if child_window.get_parent() == null:
		owner_window.add_child(child_window)
	else:
		child_window.reparent(owner_window)
	return _find_nearest_parent_window(child_window) == owner_window


static func configure_visual_input_surface(control: Control) -> void:
	if not is_instance_valid(control):
		return
	# The visible rectangle owns pointer input. Wheel events must not bubble
	# through an unhandled part of that rectangle into a covered editor below.
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.mouse_force_pass_scroll_events = false


static func get_control_pointer_screen_position(control: Control) -> Vector2i:
	if not is_instance_valid(control):
		return Vector2i.ZERO
	var screen_position := (
		control.get_screen_transform()
		* control.get_local_mouse_position()
	)
	return Vector2i(roundi(screen_position.x), roundi(screen_position.y))


static func get_control_bottom_left_screen_position(
	control: Control
) -> Vector2i:
	if not is_instance_valid(control):
		return Vector2i.ZERO
	var screen_position := (
		control.get_screen_transform()
		* Vector2(0.0, control.size.y)
	)
	return Vector2i(roundi(screen_position.x), roundi(screen_position.y))


static func _find_nearest_parent_window(node: Node) -> Window:
	if not is_instance_valid(node):
		return null
	var cursor := node.get_parent()
	while cursor != null:
		if cursor is Window:
			return cursor as Window
		cursor = cursor.get_parent()
	return null
