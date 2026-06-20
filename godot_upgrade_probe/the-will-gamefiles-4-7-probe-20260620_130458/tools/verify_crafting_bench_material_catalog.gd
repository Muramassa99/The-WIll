extends SceneTree

const CraftingBenchScene = preload("res://scenes/ui/crafting_bench_ui.tscn")
const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/crafting_bench_material_catalog_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	get_root().size = Vector2i(1280, 720)

	var player: PlayerController3D = PlayerScene.instantiate() as PlayerController3D
	get_root().add_child(player)

	var forge_controller: ForgeGridController = ForgeGridControllerScript.new()
	get_root().add_child(forge_controller)

	var crafting_ui: CraftingBenchUI = CraftingBenchScene.instantiate() as CraftingBenchUI
	get_root().add_child(crafting_ui)
	await process_frame
	await process_frame

	crafting_ui.open_for(player, forge_controller, "Material Catalog Bench")
	await process_frame
	await process_frame

	var total_catalog_count: int = crafting_ui.material_catalog.size()
	var selected_material_id: StringName = crafting_ui.selected_material_variant_id
	var armed_material_id: StringName = crafting_ui.armed_material_variant_id
	var selected_entry_exists: bool = not crafting_ui._get_material_entry(selected_material_id).is_empty()
	var armed_entry_exists: bool = armed_material_id == StringName() or not crafting_ui._get_material_entry(armed_material_id).is_empty()
	var owned_visible_count: int = crafting_ui.visible_inventory_entries.size()
	var owned_entries_have_quantity: bool = _all_entries_have_positive_quantity(crafting_ui.visible_inventory_entries)

	crafting_ui.call("_set_inventory_page", &"all")
	await process_frame
	var all_visible_count: int = crafting_ui.visible_inventory_entries.size()

	var search_query: String = ""
	if not crafting_ui.material_catalog.is_empty():
		search_query = String(crafting_ui.material_catalog[0].get("material_id", &"")).trim_prefix("mat_")
	crafting_ui.search_box.text = search_query
	crafting_ui.call("_refresh_inventory")
	await process_frame
	var search_visible_count: int = crafting_ui.visible_inventory_entries.size()

	crafting_ui.search_box.text = ""
	crafting_ui.call("_set_inventory_page", &"weapon")
	await process_frame
	var weapon_visible_count: int = crafting_ui.visible_inventory_entries.size()

	var description_nonempty: bool = not crafting_ui.material_description_text.text.strip_edges().is_empty()
	var stats_nonempty: bool = not crafting_ui.material_stats_text.text.strip_edges().is_empty()

	var lines: PackedStringArray = []
	lines.append("total_catalog_count=%d" % total_catalog_count)
	lines.append("selected_material_id=%s" % String(selected_material_id))
	lines.append("armed_material_id=%s" % String(armed_material_id))
	lines.append("selected_entry_exists=%s" % str(selected_entry_exists))
	lines.append("armed_entry_exists=%s" % str(armed_entry_exists))
	lines.append("owned_visible_count=%d" % owned_visible_count)
	lines.append("owned_entries_have_quantity=%s" % str(owned_entries_have_quantity))
	lines.append("all_visible_count=%d" % all_visible_count)
	lines.append("search_query=%s" % search_query)
	lines.append("search_visible_count=%d" % search_visible_count)
	lines.append("weapon_visible_count=%d" % weapon_visible_count)
	lines.append("description_nonempty=%s" % str(description_nonempty))
	lines.append("stats_nonempty=%s" % str(stats_nonempty))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _all_entries_have_positive_quantity(entries: Array[Dictionary]) -> bool:
	for entry: Dictionary in entries:
		if int(entry.get("quantity", 0)) <= 0:
			return false
	return true
