extends SceneTree

const CraftingBenchScene = preload("res://scenes/ui/crafting_bench_ui.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/crafting_bench_stow_ui_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var forge_controller := ForgeGridController.new()
	root.add_child(forge_controller)
	forge_controller.load_new_blank_wip("Verify Stow UI")

	var crafting_ui: CraftingBenchUI = CraftingBenchScene.instantiate() as CraftingBenchUI
	root.add_child(crafting_ui)
	crafting_ui.open_for(null, forge_controller, "Stow UI Bench")
	await process_frame
	await process_frame

	var stow_option_button: OptionButton = crafting_ui.project_stow_position_option_button
	var grip_option_button: OptionButton = crafting_ui.project_grip_style_option_button
	var current_wip: CraftedItemWIP = forge_controller.active_wip
	if current_wip != null:
		current_wip.stow_position_mode = CraftedItemWIP.STOW_LOWER_BACK
		current_wip.grip_style_mode = CraftedItemWIP.GRIP_REVERSE
	var initial_stow_mode: StringName = current_wip.stow_position_mode if current_wip != null else StringName()
	var initial_grip_mode: StringName = current_wip.grip_style_mode if current_wip != null else StringName()
	stow_option_button.select(1)
	crafting_ui._on_project_stow_position_selected(1)
	grip_option_button.select(0)
	crafting_ui._on_project_grip_style_selected(0)
	await process_frame
	crafting_ui._on_stow_position_popup_id_focused(2)
	crafting_ui._on_grip_style_popup_id_focused(0)
	await process_frame

	var lines: PackedStringArray = []
	lines.append("stow_option_count=%d" % (stow_option_button.get_item_count() if stow_option_button != null else -1))
	lines.append("stow_label_visible=%s" % str(crafting_ui.project_stow_position_label.visible))
	lines.append("stow_option_visible=%s" % str(stow_option_button.visible))
	lines.append("stow_option_disabled=%s" % str(stow_option_button.disabled))
	lines.append("grip_label_visible=%s" % str(crafting_ui.project_grip_style_label.visible))
	lines.append("grip_option_visible=%s" % str(grip_option_button.visible))
	lines.append("grip_option_disabled=%s" % str(grip_option_button.disabled))
	lines.append("initial_stow_mode=%s" % String(initial_stow_mode))
	lines.append("stow_mode_after_select=%s" % String(current_wip.stow_position_mode if current_wip != null else StringName()))
	lines.append("selected_stow_getter=%s" % String(crafting_ui._get_selected_project_stow_position()))
	lines.append("initial_grip_mode=%s" % String(initial_grip_mode))
	lines.append("grip_mode_after_select=%s" % String(current_wip.grip_style_mode if current_wip != null else StringName()))
	lines.append("selected_grip_getter=%s" % String(crafting_ui._get_selected_project_grip_style()))
	lines.append("stow_tooltip_popup_visible=%s" % str(crafting_ui.stow_hint_popup.visible))
	lines.append("grip_tooltip_popup_visible=%s" % str(crafting_ui.grip_hint_popup.visible))

	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()
