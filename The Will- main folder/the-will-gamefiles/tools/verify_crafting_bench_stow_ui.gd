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

	var option_button: OptionButton = crafting_ui.project_stow_position_option_button
	var default_mode: StringName = option_button.get_item_metadata(option_button.selected) if option_button != null and option_button.get_item_count() > 0 else StringName()
	option_button.select(1)
	crafting_ui._on_project_stow_position_selected(1)
	await process_frame
	var current_wip: CraftedItemWIP = forge_controller.active_wip
	crafting_ui._on_stow_position_popup_id_focused(2)
	await process_frame

	var lines: PackedStringArray = []
	lines.append("option_count=%d" % (option_button.get_item_count() if option_button != null else -1))
	lines.append("default_mode=%s" % String(default_mode))
	lines.append("saved_mode_after_select=%s" % String(current_wip.stow_position_mode if current_wip != null else StringName()))
	lines.append("tooltip_popup_visible=%s" % str(crafting_ui.stow_hint_popup.visible))
	lines.append("tooltip_text=%s" % crafting_ui.stow_hint_label.text)
	lines.append("side_hip_label=%s" % option_button.get_item_text(1))
	lines.append("lower_back_label=%s" % option_button.get_item_text(2))

	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()
