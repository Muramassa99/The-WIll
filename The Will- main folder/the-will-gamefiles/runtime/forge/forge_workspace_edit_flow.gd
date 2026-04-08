extends RefCounted
class_name ForgeWorkspaceEditFlow

const FREE_VIEW_DRAG_NONE := 0
const FREE_VIEW_DRAG_PAN := 1
const FREE_VIEW_DRAG_ORBIT := 2

var free_view_drag_active: bool = false
var free_view_drag_mode: int = FREE_VIEW_DRAG_NONE
var free_view_restore_mouse_position: Vector2 = Vector2.ZERO
var free_view_previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var free_view_paint_active: bool = false
var free_view_paint_has_last_grid: bool = false
var free_view_paint_last_grid_position: Vector3i = Vector3i.ZERO
var pending_edit_visual_refresh: bool = false
var pending_edit_panel_refresh: bool = false
var pending_edit_preserve_workspace_view: bool = true
var pending_edit_panel_refresh_elapsed: float = 0.0

func queue_edit_refresh(preserve_workspace_view: bool = true) -> void:
	if pending_edit_visual_refresh:
		pending_edit_preserve_workspace_view = pending_edit_preserve_workspace_view and preserve_workspace_view
	else:
		pending_edit_preserve_workspace_view = preserve_workspace_view
	pending_edit_visual_refresh = true
	pending_edit_panel_refresh = true

func process_pending_edit_refresh(
	delta: float,
	edit_panel_refresh_interval_seconds: float,
	refresh_workspace_visuals: Callable,
	flush_pending_edit_panels: Callable
) -> void:
	if pending_edit_visual_refresh:
		refresh_workspace_visuals.call(pending_edit_preserve_workspace_view)
		pending_edit_visual_refresh = false
		pending_edit_preserve_workspace_view = true
	if not pending_edit_panel_refresh:
		return
	pending_edit_panel_refresh_elapsed += maxf(delta, 0.0)
	if pending_edit_panel_refresh_elapsed < maxf(edit_panel_refresh_interval_seconds, 0.0):
		return
	flush_pending_edit_panels.call()

func flush_pending_edit_refresh(
	force: bool,
	refresh_workspace_visuals: Callable,
	flush_pending_edit_panels: Callable
) -> void:
	if pending_edit_visual_refresh:
		refresh_workspace_visuals.call(pending_edit_preserve_workspace_view)
		pending_edit_visual_refresh = false
		pending_edit_preserve_workspace_view = true
	if force:
		flush_pending_edit_panels.call()

func clear_pending_panel_refresh() -> void:
	pending_edit_panel_refresh = false
	pending_edit_panel_refresh_elapsed = 0.0

func reset_pending_edit_refresh() -> void:
	pending_edit_visual_refresh = false
	pending_edit_panel_refresh = false
	pending_edit_preserve_workspace_view = true
	pending_edit_panel_refresh_elapsed = 0.0

func begin_free_view_paint() -> void:
	free_view_paint_active = true
	free_view_paint_has_last_grid = false

func end_free_view_paint(flush_pending_edit_refresh_callback: Callable) -> void:
	free_view_paint_active = false
	free_view_paint_has_last_grid = false
	flush_pending_edit_refresh_callback.call(true)

func paint_free_view_at_screen_position(
	screen_position: Vector2,
	forge_controller: ForgeGridController,
	free_workspace_preview: ForgeWorkspacePreview,
	active_tool: StringName,
	erase_tool_id: StringName,
	place_material_cell: Callable,
	remove_material_cell: Callable
) -> void:
	if not free_view_paint_active or forge_controller == null or not is_instance_valid(free_workspace_preview):
		return
	var grid_position_variant: Variant = free_workspace_preview.screen_to_grid(screen_position)
	if grid_position_variant == null:
		return
	var grid_position: Vector3i = grid_position_variant
	if free_view_paint_has_last_grid and grid_position == free_view_paint_last_grid_position:
		return
	free_view_paint_has_last_grid = true
	free_view_paint_last_grid_position = grid_position
	if active_tool == erase_tool_id:
		remove_material_cell.call(grid_position)
	else:
		place_material_cell.call(grid_position)

func begin_free_view_drag(viewport: Viewport, capture_mouse_during_drag: bool, pan_modifier_pressed: bool) -> void:
	free_view_drag_active = true
	free_view_drag_mode = _resolve_free_view_drag_mode(pan_modifier_pressed)
	free_view_restore_mouse_position = viewport.get_mouse_position()
	free_view_previous_mouse_mode = Input.get_mouse_mode()
	if capture_mouse_during_drag:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func end_free_view_drag(viewport: Viewport, capture_mouse_during_drag: bool, restore_mouse_position: bool = true) -> void:
	if not free_view_drag_active and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	free_view_drag_active = false
	free_view_drag_mode = FREE_VIEW_DRAG_NONE
	var previous_mouse_mode: Input.MouseMode = free_view_previous_mouse_mode
	if capture_mouse_during_drag and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(previous_mouse_mode)
		if restore_mouse_position:
			viewport.warp_mouse(free_view_restore_mouse_position)
	else:
		Input.set_mouse_mode(previous_mouse_mode)

func handle_free_view_drag_motion(relative: Vector2, free_workspace_preview: ForgeWorkspacePreview, pan_modifier_pressed: bool) -> void:
	if not free_view_drag_active or not is_instance_valid(free_workspace_preview):
		return
	free_view_drag_mode = _resolve_free_view_drag_mode(pan_modifier_pressed)
	if free_view_drag_mode == FREE_VIEW_DRAG_PAN:
		free_workspace_preview.pan_by(relative)
	else:
		free_workspace_preview.orbit_by(relative)

func is_free_view_drag_active() -> bool:
	return free_view_drag_active

func is_free_view_paint_active() -> bool:
	return free_view_paint_active

func _resolve_free_view_drag_mode(pan_modifier_pressed: bool) -> int:
	return FREE_VIEW_DRAG_PAN if pan_modifier_pressed else FREE_VIEW_DRAG_ORBIT
