extends SceneTree

const PlayerScene = preload("res://scenes/player/player_character.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_inventory_layout_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	get_root().size = Vector2i(1280, 720)
	await process_frame

	var player_root: Node = PlayerScene.instantiate()
	root.add_child(player_root)
	await process_frame
	await process_frame

	var player = player_root as PlayerController3D
	var overlay: PlayerInventoryOverlay = player_root.get_node("PlayerInventoryOverlay") as PlayerInventoryOverlay
	overlay.open_page_for(player, &"inventory", "Verify Inventory")
	await process_frame
	await process_frame

	var panel: Control = overlay.get_node("Panel") as Control
	var page_scroll: ScrollContainer = overlay.get_node("Panel/MarginContainer/RootVBox/PageScroll") as ScrollContainer
	var wip_action_row: HFlowContainer = overlay.get_node("Panel/MarginContainer/RootVBox/PageScroll/StackedPages/WipStoragePage/MarginContainer/WipVBox/ActionRow") as HFlowContainer

	var panel_rect_1280x720: Rect2 = panel.get_global_rect()
	var viewport_rect_1280x720: Rect2 = get_root().get_visible_rect()
	var layout_inside_1280x720: bool = viewport_rect_1280x720.encloses(panel_rect_1280x720)
	var page_scroll_size_1280x720: Vector2 = page_scroll.size

	get_root().size = Vector2i(1024, 576)
	overlay.open_page_for(player, &"wip_storage", "Verify Inventory")
	await process_frame
	await process_frame

	var panel_rect_1024x576: Rect2 = panel.get_global_rect()
	var viewport_rect_1024x576: Rect2 = get_root().get_visible_rect()
	var layout_inside_1024x576: bool = viewport_rect_1024x576.encloses(panel_rect_1024x576)
	var page_scroll_size_1024x576: Vector2 = page_scroll.size
	var vertical_scroll_max_1024x576: float = page_scroll.get_v_scroll_bar().max_value if page_scroll.get_v_scroll_bar() != null else 0.0
	var vertical_scroll_page_1024x576: float = page_scroll.get_v_scroll_bar().page if page_scroll.get_v_scroll_bar() != null else 0.0

	var lines: PackedStringArray = []
	lines.append("overlay_loaded=%s" % str(overlay != null))
	lines.append("page_scroll_loaded=%s" % str(page_scroll != null))
	lines.append("wip_action_row_is_flow=%s" % str(wip_action_row != null))
	lines.append("layout_inside_1280x720=%s" % str(layout_inside_1280x720))
	lines.append("panel_rect_1280x720=%s" % str(panel_rect_1280x720))
	lines.append("viewport_rect_1280x720=%s" % str(viewport_rect_1280x720))
	lines.append("page_scroll_size_1280x720=%s" % str(page_scroll_size_1280x720))
	lines.append("layout_inside_1024x576=%s" % str(layout_inside_1024x576))
	lines.append("panel_rect_1024x576=%s" % str(panel_rect_1024x576))
	lines.append("viewport_rect_1024x576=%s" % str(viewport_rect_1024x576))
	lines.append("page_scroll_size_1024x576=%s" % str(page_scroll_size_1024x576))
	lines.append("vertical_scroll_max_1024x576=%s" % str(vertical_scroll_max_1024x576))
	lines.append("vertical_scroll_page_1024x576=%s" % str(vertical_scroll_page_1024x576))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()
