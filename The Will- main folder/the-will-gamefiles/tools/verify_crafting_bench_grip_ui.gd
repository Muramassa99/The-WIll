extends SceneTree

const CraftingBenchScene = preload("res://scenes/ui/crafting_bench_ui.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/crafting_bench_grip_ui_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var forge_controller := ForgeGridController.new()
	root.add_child(forge_controller)
	forge_controller.load_new_blank_wip("Verify Grip UI")

	var crafting_ui: CraftingBenchUI = CraftingBenchScene.instantiate() as CraftingBenchUI
	root.add_child(crafting_ui)
	crafting_ui.open_for(null, forge_controller, "Grip UI Bench")
	await process_frame
	await process_frame

	var option_button: OptionButton = crafting_ui.project_grip_style_option_button
	var default_mode: StringName = option_button.get_item_metadata(option_button.selected) if option_button != null and option_button.get_item_count() > 0 else StringName()
	var grip_popup: PopupMenu = option_button.get_popup() if option_button != null else null
	var melee_reverse_disabled: bool = grip_popup.is_item_disabled(1) if grip_popup != null and grip_popup.get_item_count() > 1 else true

	option_button.select(1)
	crafting_ui._on_project_grip_style_selected(1)
	await process_frame
	var melee_wip: CraftedItemWIP = forge_controller.active_wip
	crafting_ui._on_grip_style_popup_id_focused(1)
	await process_frame
	var grip_tooltip_popup_visible: bool = crafting_ui.grip_hint_popup.visible
	var grip_tooltip_text: String = crafting_ui.grip_hint_label.text

	forge_controller.load_debug_sample_preset(forge_controller.get_sample_bow_preset_id())
	await process_frame
	await process_frame

	var bow_wip: CraftedItemWIP = forge_controller.active_wip
	var bow_reverse_disabled: bool = grip_popup.is_item_disabled(1) if grip_popup != null and grip_popup.get_item_count() > 1 else false
	option_button.select(1)
	crafting_ui._on_project_grip_style_selected(1)
	await process_frame

	var lines: PackedStringArray = []
	lines.append("option_count=%d" % (option_button.get_item_count() if option_button != null else -1))
	lines.append("default_mode=%s" % String(default_mode))
	lines.append("melee_reverse_disabled=%s" % str(melee_reverse_disabled))
	lines.append("saved_mode_after_reverse_select=%s" % String(melee_wip.grip_style_mode if melee_wip != null else StringName()))
	lines.append("tooltip_popup_visible=%s" % str(grip_tooltip_popup_visible))
	lines.append("tooltip_text=%s" % grip_tooltip_text)
	lines.append("normal_label=%s" % option_button.get_item_text(0))
	lines.append("reverse_label=%s" % option_button.get_item_text(1))
	lines.append("bow_reverse_disabled=%s" % str(bow_reverse_disabled))
	lines.append("bow_mode_after_forced_reverse_select=%s" % String(bow_wip.grip_style_mode if bow_wip != null else StringName()))

	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()
