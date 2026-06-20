extends RefCounted
class_name ForgeWorkspaceInteractionPresenter

var held_layer_direction: int = 0
var held_layer_delay_remaining: float = 0.0
var held_layer_repeat_accumulator: float = 0.0

func get_workspace_orbit_mouse_button(workspace_orbit_mouse_button: MouseButton) -> MouseButton:
	return workspace_orbit_mouse_button

func is_action_pressed_if_available(event: InputEvent, action_name: StringName) -> bool:
	return InputMap.has_action(action_name) and event.is_action_pressed(action_name)

func is_initial_action_press(event: InputEvent, action_name: StringName) -> bool:
	if not is_action_pressed_if_available(event, action_name):
		return false
	if event is InputEventKey and (event as InputEventKey).echo:
		return false
	return true

func is_action_released_if_available(event: InputEvent, action_name: StringName) -> bool:
	return InputMap.has_action(action_name) and event.is_action_released(action_name)

func resolve_inventory_page(page_id: StringName) -> StringName:
	return page_id

func resolve_active_tool(tool_id: StringName) -> StringName:
	return tool_id

func resolve_active_plane_state(
	current_layer: int,
	plane_id: StringName,
	forge_controller: ForgeGridController,
	get_default_layer_for_plane: Callable,
	get_max_layer_for_plane: Callable
) -> Dictionary:
	var resolved_layer: int = clampi(current_layer, 0, int(get_max_layer_for_plane.call(plane_id)))
	if forge_controller != null:
		resolved_layer = int(get_default_layer_for_plane.call(plane_id))
	return {
		"active_plane": plane_id,
		"active_layer": resolved_layer,
	}

func resolve_stepped_layer(
	current_layer: int,
	active_plane: StringName,
	delta: int,
	forge_controller: ForgeGridController,
	plane_xy: StringName,
	get_max_layer_for_plane: Callable
) -> int:
	var resolved_layer: int = clampi(
		current_layer + delta,
		0,
		int(get_max_layer_for_plane.call(active_plane))
	)
	if forge_controller != null and active_plane == plane_xy:
		forge_controller.set_active_layer_index(resolved_layer)
	return resolved_layer

func resolve_inventory_selection(
	index: int,
	visible_inventory_entries: Array[Dictionary],
	selected_material_variant_id: StringName,
	armed_material_variant_id: StringName
) -> Dictionary:
	if index < 0 or index >= visible_inventory_entries.size():
		return {}
	var entry: Dictionary = visible_inventory_entries[index]
	var material_id: StringName = entry.get("material_id", &"")
	var quantity: int = int(entry.get("quantity", 0))
	var can_arm: bool = quantity > 0 or bool(entry.get("is_placeable_without_inventory", false))
	if material_id == selected_material_variant_id:
		if can_arm:
			armed_material_variant_id = StringName() if armed_material_variant_id == material_id else material_id
	else:
		selected_material_variant_id = material_id
		armed_material_variant_id = material_id if can_arm else StringName()
	return {
		"selected_material_variant_id": selected_material_variant_id,
		"armed_material_variant_id": armed_material_variant_id,
	}

func toggle_workspace_mode(
	current_mode: StringName,
	free_workspace_mode: StringName,
	plane_workspace_mode: StringName
) -> StringName:
	return plane_workspace_mode if current_mode == free_workspace_mode else free_workspace_mode

func handle_plane_cell_place_requested(
	active_tool: StringName,
	tool_pick: StringName,
	tool_erase: StringName,
	grid_position: Vector3i,
	pick_material_from_grid: Callable,
	remove_cell: Callable,
	place_material_cell: Callable
) -> void:
	if active_tool == tool_pick:
		pick_material_from_grid.call(grid_position)
		return
	if active_tool == tool_erase:
		remove_cell.call(grid_position)
		return
	place_material_cell.call(grid_position)

func handle_free_view_panel_gui_input(
	event: InputEvent,
	forge_controller: ForgeGridController,
	free_workspace_preview: ForgeWorkspacePreview,
	zoom_step: float
) -> void:
	if forge_controller == null or not is_instance_valid(free_workspace_preview):
		return
	if event is not InputEventMouseButton:
		return
	var mouse_button: InputEventMouseButton = event
	if not mouse_button.pressed:
		return
	if mouse_button.ctrl_pressed and (
		mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP
		or mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN
	):
		return
	if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
		free_workspace_preview.zoom_by(-zoom_step)
		return
	if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		free_workspace_preview.zoom_by(zoom_step)

func begin_free_view_drag(
	workspace_edit_flow: ForgeWorkspaceEditFlow,
	viewport: Viewport,
	capture_mouse_during_drag: bool,
	pan_modifier_keycode: Key,
	end_free_view_paint_callback: Callable
) -> void:
	end_free_view_paint_callback.call()
	workspace_edit_flow.begin_free_view_drag(
		viewport,
		capture_mouse_during_drag,
		Input.is_key_pressed(pan_modifier_keycode)
	)

func end_free_view_drag(
	workspace_edit_flow: ForgeWorkspaceEditFlow,
	viewport: Viewport,
	capture_mouse_during_drag: bool,
	restore_mouse_position: bool = true
) -> void:
	workspace_edit_flow.end_free_view_drag(
		viewport,
		capture_mouse_during_drag,
		restore_mouse_position
	)

func handle_free_view_drag_motion_state(
	workspace_edit_flow: ForgeWorkspaceEditFlow,
	relative: Vector2,
	free_workspace_preview: ForgeWorkspacePreview,
	pan_modifier_keycode: Key
) -> void:
	workspace_edit_flow.handle_free_view_drag_motion(
		relative,
		free_workspace_preview,
		Input.is_key_pressed(pan_modifier_keycode)
	)

func begin_free_view_paint(workspace_edit_flow: ForgeWorkspaceEditFlow) -> void:
	workspace_edit_flow.begin_free_view_paint()

func end_free_view_paint(
	workspace_edit_flow: ForgeWorkspaceEditFlow,
	flush_pending_edit_refresh: Callable
) -> void:
	workspace_edit_flow.end_free_view_paint(flush_pending_edit_refresh)

func paint_free_view_at_screen_position_state(
	workspace_edit_flow: ForgeWorkspaceEditFlow,
	screen_position: Vector2,
	forge_controller: ForgeGridController,
	free_workspace_preview: ForgeWorkspacePreview,
	active_tool: StringName,
	erase_tool_id: StringName,
	place_material_cell: Callable,
	remove_material_cell: Callable
) -> void:
	workspace_edit_flow.paint_free_view_at_screen_position(
		screen_position,
		forge_controller,
		free_workspace_preview,
		active_tool,
		erase_tool_id,
		place_material_cell,
		remove_material_cell
	)

func handle_free_view_gui_input(
	event: InputEvent,
	forge_controller: ForgeGridController,
	free_workspace_preview: ForgeWorkspacePreview,
	active_tool: StringName,
	tool_pick: StringName,
	workspace_edit_flow: ForgeWorkspaceEditFlow,
	orbit_mouse_button: MouseButton,
	zoom_step: float,
	pick_material_from_screen_position: Callable,
	begin_free_view_drag_callback: Callable,
	end_free_view_drag_callback: Callable,
	begin_free_view_paint_callback: Callable,
	end_free_view_paint_callback: Callable,
	paint_free_view_at_screen_position_callback: Callable,
	handle_free_view_drag_motion_callback: Callable
) -> void:
	if forge_controller == null or not is_instance_valid(free_workspace_preview):
		return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.ctrl_pressed and (
			mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP
			or mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN
		):
			return
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			free_workspace_preview.zoom_by(-zoom_step)
			return
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			free_workspace_preview.zoom_by(zoom_step)
			return
		if mouse_button.button_index == orbit_mouse_button:
			if mouse_button.pressed:
				begin_free_view_drag_callback.call()
			else:
				end_free_view_drag_callback.call()
			return
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			end_free_view_paint_callback.call()
			return
		if not mouse_button.pressed:
			return
		if mouse_button.ctrl_pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
			pick_material_from_screen_position.call(mouse_button.position)
			end_free_view_paint_callback.call()
			return
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if active_tool == tool_pick:
				pick_material_from_screen_position.call(mouse_button.position)
				end_free_view_paint_callback.call()
			else:
				begin_free_view_paint_callback.call()
				paint_free_view_at_screen_position_callback.call(mouse_button.position)
			return
	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		if workspace_edit_flow.is_free_view_drag_active():
			handle_free_view_drag_motion_callback.call(motion_event.relative)
			return
		if workspace_edit_flow.is_free_view_paint_active():
			paint_free_view_at_screen_position_callback.call(motion_event.position)

func begin_layer_hold(direction: int, repeat_delay_seconds: float) -> void:
	held_layer_direction = 1 if direction > 0 else -1 if direction < 0 else 0
	held_layer_delay_remaining = maxf(repeat_delay_seconds, 0.0)
	held_layer_repeat_accumulator = 0.0

func clear_layer_hold() -> void:
	held_layer_direction = 0
	held_layer_delay_remaining = 0.0
	held_layer_repeat_accumulator = 0.0

func process_layer_hold_repeat(delta: float, repeat_rate_hz: float, step_layer: Callable) -> void:
	if held_layer_direction == 0:
		return
	var action_name: StringName = &"forge_layer_up" if held_layer_direction > 0 else &"forge_layer_down"
	if not InputMap.has_action(action_name) or not Input.is_action_pressed(action_name):
		clear_layer_hold()
		return
	if held_layer_delay_remaining > 0.0:
		held_layer_delay_remaining -= delta
		if held_layer_delay_remaining > 0.0:
			return
		delta = -held_layer_delay_remaining
		held_layer_delay_remaining = 0.0
	var repeat_interval: float = 1.0 / maxf(repeat_rate_hz, 0.001)
	held_layer_repeat_accumulator += delta
	var repeat_step_count: int = int(floor((held_layer_repeat_accumulator + 0.0001) / repeat_interval))
	if repeat_step_count <= 0:
		return
	held_layer_repeat_accumulator -= repeat_interval * float(repeat_step_count)
	for _repeat_index in range(repeat_step_count):
		step_layer.call(held_layer_direction)
