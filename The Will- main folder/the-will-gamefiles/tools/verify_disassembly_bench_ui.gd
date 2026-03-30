extends SceneTree

const DisassemblyBenchScene = preload("res://scenes/ui/disassembly_bench_ui.tscn")
const PlayerBodyInventoryStateScript = preload("res://core/models/player_body_inventory_state.gd")
const PlayerForgeInventoryStateScript = preload("res://core/models/player_forge_inventory_state.gd")
const StoredItemInstanceScript = preload("res://core/models/stored_item_instance.gd")

const TEMP_BODY_SAVE_PATH := "c:/WORKSPACE/tmp_verify_disassembly_body_state.tres"
const OUTPUT_PATH := "c:/WORKSPACE/disassembly_bench_results.txt"

class TestPlayer:
	var ui_mode_enabled: bool = false
	var body_inventory_state = PlayerBodyInventoryStateScript.new()
	var forge_inventory_state = PlayerForgeInventoryStateScript.new()

	func _init() -> void:
		body_inventory_state.save_file_path = TEMP_BODY_SAVE_PATH

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

	func get_body_inventory_state():
		return body_inventory_state

	func get_forge_inventory_state():
		return forge_inventory_state

	func ensure_body_inventory_seeded(seed_def: Resource = null) -> void:
		if seed_def == null or seed_def.is_empty():
			return
		if not body_inventory_state.get_owned_items().is_empty():
			return
		for seed_entry in seed_def.entries:
			if seed_entry == null or seed_entry.stack_count <= 0:
				continue
			var stored_item = StoredItemInstanceScript.new()
			stored_item.item_kind = seed_entry.item_kind
			stored_item.display_name = seed_entry.display_name
			stored_item.stack_count = seed_entry.stack_count
			stored_item.raw_drop_id = seed_entry.raw_drop_id
			stored_item.is_disassemblable = seed_entry.is_disassemblable
			body_inventory_state.add_item(stored_item)

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var test_player := TestPlayer.new()

	get_root().size = Vector2i(1280, 720)
	await process_frame

	var disassembly_ui = DisassemblyBenchScene.instantiate()
	get_root().add_child(disassembly_ui)
	await process_frame
	await process_frame

	disassembly_ui.call("open_for", test_player, "Verifier Bench")
	await process_frame
	await process_frame

	var panel_control: Control = disassembly_ui.get_node("Panel") as Control
	var inventory_list: ItemList = disassembly_ui.get_node("Panel/MarginContainer/RootVBox/MainScroll/MainHBox/InventoryPanel/MarginContainer/InventoryVBox/InventoryList") as ItemList
	var output_preview_list: ItemList = disassembly_ui.get_node("Panel/MarginContainer/RootVBox/MainScroll/MainHBox/OutputPanel/MarginContainer/OutputVBox/OutputPreviewList") as ItemList
	var selected_list: ItemList = disassembly_ui.get_node("Panel/MarginContainer/RootVBox/MainScroll/MainHBox/SelectedPanel/MarginContainer/SelectedVBox/SelectedList") as ItemList
	var check_box: CheckBox = disassembly_ui.get_node("Panel/MarginContainer/RootVBox/MainScroll/MainHBox/OutputPanel/MarginContainer/OutputVBox/WarningPanel/MarginContainer/WarningVBox/IrreversibleCheckBox") as CheckBox
	var disassemble_button: Button = disassembly_ui.get_node("Panel/MarginContainer/RootVBox/MainScroll/MainHBox/OutputPanel/MarginContainer/OutputVBox/ActionRow/DisassembleButton") as Button

	var panel_rect_1280x720: Rect2 = panel_control.get_global_rect()
	var viewport_rect_1280x720: Rect2 = get_root().get_visible_rect()
	var layout_inside_1280x720: bool = viewport_rect_1280x720.encloses(panel_rect_1280x720)
	var inventory_item_count_before: int = inventory_list.item_count
	var preview_count_before: int = output_preview_list.item_count
	var disassemble_disabled_before: bool = disassemble_button.disabled

	if inventory_list.item_count > 0 and not inventory_list.is_item_disabled(0):
		inventory_list.emit_signal("item_clicked", 0, Vector2.ZERO, MOUSE_BUTTON_LEFT)
	await process_frame
	await process_frame

	var selected_count_after_pick: int = selected_list.item_count
	var preview_count_after_pick: int = output_preview_list.item_count
	var disassemble_disabled_after_pick: bool = disassemble_button.disabled

	check_box.button_pressed = true
	await process_frame
	await process_frame
	var disassemble_disabled_after_check: bool = disassemble_button.disabled
	disassemble_button.emit_signal("pressed")
	await process_frame
	await process_frame

	var body_remaining_after_commit: int = test_player.get_body_inventory_state().get_owned_items().size()
	var forge_wood_quantity_after_commit: int = test_player.get_forge_inventory_state().get_quantity(&"mat_wood_gray")

	get_root().size = Vector2i(1024, 576)
	await process_frame
	await process_frame
	var panel_rect_1024x576: Rect2 = panel_control.get_global_rect()
	var viewport_rect_1024x576: Rect2 = get_root().get_visible_rect()
	var layout_inside_1024x576: bool = viewport_rect_1024x576.encloses(panel_rect_1024x576)

	var lines: PackedStringArray = []
	lines.append("ui_loaded=%s" % str(disassembly_ui != null))
	lines.append("layout_inside_1280x720=%s" % str(layout_inside_1280x720))
	lines.append("panel_rect_1280x720=%s" % str(panel_rect_1280x720))
	lines.append("viewport_rect_1280x720=%s" % str(viewport_rect_1280x720))
	lines.append("inventory_item_count_before=%d" % inventory_item_count_before)
	lines.append("preview_count_before=%d" % preview_count_before)
	lines.append("selected_count_after_pick=%d" % selected_count_after_pick)
	lines.append("preview_count_after_pick=%d" % preview_count_after_pick)
	lines.append("disassemble_disabled_before=%s" % str(disassemble_disabled_before))
	lines.append("disassemble_disabled_after_pick=%s" % str(disassemble_disabled_after_pick))
	lines.append("disassemble_disabled_after_check=%s" % str(disassemble_disabled_after_check))
	lines.append("body_remaining_after_commit=%d" % body_remaining_after_commit)
	lines.append("forge_wood_quantity_after_commit=%d" % forge_wood_quantity_after_commit)
	lines.append("layout_inside_1024x576=%s" % str(layout_inside_1024x576))
	lines.append("panel_rect_1024x576=%s" % str(panel_rect_1024x576))
	lines.append("viewport_rect_1024x576=%s" % str(viewport_rect_1024x576))

	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	_cleanup_temp_file(TEMP_BODY_SAVE_PATH)
	quit()

func _cleanup_temp_file(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
