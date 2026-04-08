extends RefCounted
class_name ForgeBenchSessionPresenter

const DEFAULT_SUBTITLE := "Author matter on the full forge work area. The right side manages processed material stacks, the center edits one shared WIP, and the top menus group project, status, view, build, and workflow actions."

func open_session(
	player,
	forge_controller: ForgeGridController,
	bench_name: String,
	title_label: Label,
	subtitle_label: Label,
	panel: Control,
	debug_popup: PopupPanel,
	hide_stow_hint: Callable,
	hide_grip_hint: Callable,
	queue_layout_refresh: Callable,
	reset_material_lookup_cache: Callable,
	clear_layer_hold: Callable,
	restore_preferred_project: Callable,
	ensure_wip_for_editing: Callable,
	get_default_layer_for_plane: Callable,
	get_max_layer_for_plane: Callable,
	rebuild_workflow_menu: Callable,
	build_material_catalog: Callable,
	refresh_all: Callable,
	on_active_wip_changed: Callable,
	on_active_test_print_changed: Callable
) -> Dictionary:
	reset_material_lookup_cache.call()
	clear_layer_hold.call()
	title_label.text = "%s Forge Station" % bench_name
	subtitle_label.text = DEFAULT_SUBTITLE
	panel.visible = true
	hide_stow_hint.call()
	hide_grip_hint.call()
	debug_popup.hide()
	queue_layout_refresh.call()
	if player != null:
		player.set_ui_mode_enabled(true)
	_connect_controller_signals(
		forge_controller,
		on_active_wip_changed,
		on_active_test_print_changed
	)
	var current_wip: CraftedItemWIP = forge_controller.active_wip if forge_controller != null else null
	if current_wip == null:
		var restore_result: Dictionary = restore_preferred_project.call()
		current_wip = restore_result.get("wip", null) as CraftedItemWIP
	if current_wip == null:
		current_wip = ensure_wip_for_editing.call()
	var active_plane: StringName = &"xy"
	var active_layer: int = int(get_default_layer_for_plane.call(active_plane))
	if current_wip != null and forge_controller != null:
		active_layer = clampi(
			forge_controller.get_active_layer_index(),
			0,
			int(get_max_layer_for_plane.call(active_plane))
		)
	if player != null and forge_controller != null:
		player.ensure_forge_inventory_seeded(
			forge_controller.build_default_material_lookup(),
			forge_controller.get_inventory_seed_def(),
			forge_controller.get_inventory_seed_quantity(),
			forge_controller.get_inventory_seed_bonus_quantity()
		)
	rebuild_workflow_menu.call()
	build_material_catalog.call()
	refresh_all.call(false)
	return {
		"active_plane": active_plane,
		"active_layer": active_layer,
		"debug_status_dirty": true,
	}

func close_session(
	active_player,
	panel: Control,
	debug_popup: PopupPanel,
	end_free_view_drag: Callable,
	end_free_view_paint: Callable,
	clear_layer_hold: Callable,
	reset_pending_edit_refresh: Callable,
	reset_material_lookup_cache: Callable,
	hide_stow_hint: Callable,
	hide_grip_hint: Callable
) -> Dictionary:
	if not panel.visible:
		return {
			"closed": false,
			"active_player": active_player,
		}
	end_free_view_drag.call(false)
	end_free_view_paint.call()
	clear_layer_hold.call()
	reset_pending_edit_refresh.call()
	reset_material_lookup_cache.call()
	hide_stow_hint.call()
	hide_grip_hint.call()
	debug_popup.hide()
	panel.visible = false
	if active_player != null:
		active_player.set_ui_mode_enabled(false)
	return {
		"closed": true,
		"active_player": null,
	}

func _connect_controller_signals(
	forge_controller: ForgeGridController,
	on_active_wip_changed: Callable,
	on_active_test_print_changed: Callable
) -> void:
	if forge_controller == null:
		return
	if not forge_controller.active_wip_changed.is_connected(on_active_wip_changed):
		forge_controller.active_wip_changed.connect(on_active_wip_changed)
	if not forge_controller.active_test_print_changed.is_connected(on_active_test_print_changed):
		forge_controller.active_test_print_changed.connect(on_active_test_print_changed)
