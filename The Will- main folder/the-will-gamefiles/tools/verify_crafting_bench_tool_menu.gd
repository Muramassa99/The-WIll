extends SceneTree

const CraftingBenchScene = preload("res://scenes/ui/crafting_bench_ui.tscn")
const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")
const ForgeWorkspaceShapeToolPresenterScript = preload("res://runtime/forge/forge_workspace_shape_tool_presenter.gd")
const ForgeStage2SelectionPresenterScript = preload("res://runtime/forge/forge_stage2_selection_presenter.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/crafting_bench_tool_menu_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	get_root().size = Vector2i(1280, 720)

	var forge_controller: ForgeGridController = ForgeGridControllerScript.new()
	forge_controller.load_new_blank_wip_for_builder_path("Tool Menu Test", CraftedItemWIP.BUILDER_PATH_MELEE)
	_seed_cells(forge_controller)
	get_root().add_child(forge_controller)

	var player: PlayerController3D = PlayerScene.instantiate() as PlayerController3D
	get_root().add_child(player)

	var crafting_ui: CraftingBenchUI = CraftingBenchScene.instantiate() as CraftingBenchUI
	get_root().add_child(crafting_ui)
	await process_frame
	await process_frame

	crafting_ui.open_for(player, forge_controller, "Tool Menu Test Bench")
	await process_frame
	await process_frame

	var tool_popup: PopupMenu = crafting_ui.tool_menu_button.get_popup()
	crafting_ui.call("_rebuild_tool_menu")
	var freehand_has_no_runtime_adjustments: bool = _popup_has_item_text(tool_popup, "No runtime adjustments")

	crafting_ui.call("_set_active_tool", ForgeWorkspaceShapeToolPresenterScript.FAMILY_RECTANGLE)
	await process_frame
	crafting_ui.call("_rebuild_tool_menu")
	var rectangle_tool_menu_has_shape_line: bool = _popup_contains_prefix(tool_popup, "Shape Tool: ")
	var rectangle_tool_menu_has_size_line: bool = _popup_contains_prefix(tool_popup, "Click Size: ")
	var rectangle_tool_menu_has_size_a_line: bool = _popup_contains_prefix(tool_popup, "Size A: ")
	var rectangle_tool_menu_has_size_b_line: bool = _popup_contains_prefix(tool_popup, "Size B: ")
	var rectangle_tool_menu_has_size_a_down: bool = _popup_has_item_text(tool_popup, "Size A -")
	var rectangle_tool_menu_has_size_a_up: bool = _popup_has_item_text(tool_popup, "Size A +")
	var rectangle_tool_menu_has_size_b_down: bool = _popup_has_item_text(tool_popup, "Size B -")
	var rectangle_tool_menu_has_size_b_up: bool = _popup_has_item_text(tool_popup, "Size B +")
	var rectangle_tool_menu_has_mode_line: bool = _popup_contains_prefix(tool_popup, "Mode: ")
	var rectangle_tool_menu_has_draw_action: bool = _popup_has_item_text(tool_popup, "Set Shape to Draw")
	var rectangle_tool_menu_has_erase_action: bool = _popup_has_item_text(tool_popup, "Set Shape to Erase")
	var rectangle_tool_menu_has_rotate_left: bool = _popup_has_item_text(tool_popup, "Rotate Shape -90 deg")
	var rectangle_tool_menu_has_rotate_right: bool = _popup_has_item_text(tool_popup, "Rotate Shape +90 deg")
	var rectangle_tool_menu_rotate_left_enabled: bool = not _popup_item_disabled(tool_popup, "Rotate Shape -90 deg")
	var rectangle_tool_menu_rotate_right_enabled: bool = not _popup_item_disabled(tool_popup, "Rotate Shape +90 deg")
	var tool_popup_persists_on_item_selection: bool = not tool_popup.hide_on_item_selection

	var menu_ids: Dictionary = crafting_ui.call("_get_action_menu_ids")
	_open_tool_popup(crafting_ui)
	await process_frame
	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("tool_shape_rotate_right", -1)))
	await process_frame
	crafting_ui.call("_rebuild_tool_menu")
	var rectangle_rotation_changed_to_ninety: bool = _popup_has_item_text(tool_popup, "Rotation: 90 deg")
	var tool_popup_visible_after_shape_rotate: bool = tool_popup.visible

	crafting_ui.call("_initialize_stage2_for_active_wip")
	await process_frame
	await process_frame
	crafting_ui.call("_toggle_stage2_refinement_mode")
	await process_frame
	await process_frame

	crafting_ui.call("_rebuild_tool_menu")
	var stage2_pointer_tool_menu_has_radius_line: bool = _popup_contains_prefix(tool_popup, "Radius: ")
	var stage2_pointer_tool_menu_has_radius_down: bool = _popup_has_item_text(tool_popup, "Radius -")
	var stage2_pointer_tool_menu_has_radius_up: bool = _popup_has_item_text(tool_popup, "Radius +")
	var stage2_pointer_tool_menu_has_amount_line: bool = _popup_contains_prefix(tool_popup, "Amount: ")
	var stage2_pointer_tool_menu_has_amount_down: bool = _popup_has_item_text(tool_popup, "Amount -")
	var stage2_pointer_tool_menu_has_amount_up: bool = _popup_has_item_text(tool_popup, "Amount +")

	var amount_before_down: float = float(crafting_ui.get("stage2_tool_amount_ratio"))
	_open_tool_popup(crafting_ui)
	await process_frame
	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("tool_amount_down", -1)))
	await process_frame
	var amount_after_down: float = float(crafting_ui.get("stage2_tool_amount_ratio"))
	var tool_amount_decreased_via_menu: bool = amount_after_down < amount_before_down
	var tool_popup_visible_after_amount_change: bool = tool_popup.visible

	var radius_before_up: float = float(crafting_ui.get("stage2_brush_radius_meters"))
	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("tool_radius_up", -1)))
	await process_frame
	var radius_after_up: float = float(crafting_ui.get("stage2_brush_radius_meters"))
	var tool_radius_increased_via_menu: bool = radius_after_up > radius_before_up

	crafting_ui.call("_set_active_tool", ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FACE_FILLET)
	await process_frame
	crafting_ui.call("_rebuild_tool_menu")
	var stage2_selection_tool_menu_has_amount_line: bool = _popup_contains_prefix(tool_popup, "Amount: ")
	var stage2_selection_tool_menu_hides_radius_line: bool = not _popup_contains_prefix(tool_popup, "Radius: ")

	var lines: PackedStringArray = []
	lines.append("tool_menu_exists=%s" % str(crafting_ui.tool_menu_button != null))
	lines.append("freehand_has_no_runtime_adjustments=%s" % str(freehand_has_no_runtime_adjustments))
	lines.append("rectangle_tool_menu_has_shape_line=%s" % str(rectangle_tool_menu_has_shape_line))
	lines.append("rectangle_tool_menu_has_size_line=%s" % str(rectangle_tool_menu_has_size_line))
	lines.append("rectangle_tool_menu_has_size_a_line=%s" % str(rectangle_tool_menu_has_size_a_line))
	lines.append("rectangle_tool_menu_has_size_b_line=%s" % str(rectangle_tool_menu_has_size_b_line))
	lines.append("rectangle_tool_menu_has_size_a_down=%s" % str(rectangle_tool_menu_has_size_a_down))
	lines.append("rectangle_tool_menu_has_size_a_up=%s" % str(rectangle_tool_menu_has_size_a_up))
	lines.append("rectangle_tool_menu_has_size_b_down=%s" % str(rectangle_tool_menu_has_size_b_down))
	lines.append("rectangle_tool_menu_has_size_b_up=%s" % str(rectangle_tool_menu_has_size_b_up))
	lines.append("rectangle_tool_menu_has_mode_line=%s" % str(rectangle_tool_menu_has_mode_line))
	lines.append("rectangle_tool_menu_has_draw_action=%s" % str(rectangle_tool_menu_has_draw_action))
	lines.append("rectangle_tool_menu_has_erase_action=%s" % str(rectangle_tool_menu_has_erase_action))
	lines.append("rectangle_tool_menu_has_rotate_left=%s" % str(rectangle_tool_menu_has_rotate_left))
	lines.append("rectangle_tool_menu_has_rotate_right=%s" % str(rectangle_tool_menu_has_rotate_right))
	lines.append("rectangle_tool_menu_rotate_left_enabled=%s" % str(rectangle_tool_menu_rotate_left_enabled))
	lines.append("rectangle_tool_menu_rotate_right_enabled=%s" % str(rectangle_tool_menu_rotate_right_enabled))
	lines.append("tool_popup_persists_on_item_selection=%s" % str(tool_popup_persists_on_item_selection))
	lines.append("rectangle_rotation_changed_to_ninety=%s" % str(rectangle_rotation_changed_to_ninety))
	lines.append("tool_popup_visible_after_shape_rotate=%s" % str(tool_popup_visible_after_shape_rotate))
	lines.append("stage2_pointer_tool_menu_has_radius_line=%s" % str(stage2_pointer_tool_menu_has_radius_line))
	lines.append("stage2_pointer_tool_menu_has_radius_down=%s" % str(stage2_pointer_tool_menu_has_radius_down))
	lines.append("stage2_pointer_tool_menu_has_radius_up=%s" % str(stage2_pointer_tool_menu_has_radius_up))
	lines.append("stage2_pointer_tool_menu_has_amount_line=%s" % str(stage2_pointer_tool_menu_has_amount_line))
	lines.append("stage2_pointer_tool_menu_has_amount_down=%s" % str(stage2_pointer_tool_menu_has_amount_down))
	lines.append("stage2_pointer_tool_menu_has_amount_up=%s" % str(stage2_pointer_tool_menu_has_amount_up))
	lines.append("tool_amount_decreased_via_menu=%s" % str(tool_amount_decreased_via_menu))
	lines.append("tool_popup_visible_after_amount_change=%s" % str(tool_popup_visible_after_amount_change))
	lines.append("tool_radius_increased_via_menu=%s" % str(tool_radius_increased_via_menu))
	lines.append("stage2_selection_tool_menu_has_amount_line=%s" % str(stage2_selection_tool_menu_has_amount_line))
	lines.append("stage2_selection_tool_menu_hides_radius_line=%s" % str(stage2_selection_tool_menu_hides_radius_line))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _seed_cells(forge_controller: ForgeGridController) -> void:
	for z: int in range(2):
		for y: int in range(2):
			for x: int in range(4):
				forge_controller.set_material_at(Vector3i(x, y, z), &"mat_iron_gray")

func _popup_has_item_text(popup: PopupMenu, item_text: String) -> bool:
	if popup == null:
		return false
	for item_index: int in range(popup.get_item_count()):
		if popup.get_item_text(item_index) == item_text:
			return true
	return false

func _popup_contains_prefix(popup: PopupMenu, prefix_text: String) -> bool:
	if popup == null:
		return false
	for item_index: int in range(popup.get_item_count()):
		if popup.get_item_text(item_index).begins_with(prefix_text):
			return true
	return false

func _popup_item_disabled(popup: PopupMenu, item_text: String) -> bool:
	if popup == null:
		return true
	for item_index: int in range(popup.get_item_count()):
		if popup.get_item_text(item_index) == item_text:
			return popup.is_item_disabled(item_index)
	return true

func _open_tool_popup(crafting_ui: CraftingBenchUI) -> void:
	if crafting_ui == null or crafting_ui.tool_menu_button == null:
		return
	crafting_ui.tool_menu_button.show_popup()
