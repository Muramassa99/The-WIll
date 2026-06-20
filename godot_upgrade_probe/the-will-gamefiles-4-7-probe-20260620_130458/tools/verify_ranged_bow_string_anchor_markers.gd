extends SceneTree

const CraftingBenchScene = preload("res://scenes/ui/crafting_bench_ui.tscn")
const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")
const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	get_root().size = Vector2i(1280, 720)

	var player: PlayerController3D = PlayerScene.instantiate() as PlayerController3D
	get_root().add_child(player)
	await process_frame
	await process_frame

	var forge_controller: ForgeGridController = ForgeGridControllerScript.new()
	get_root().add_child(forge_controller)

	var crafting_ui: CraftingBenchUI = CraftingBenchScene.instantiate() as CraftingBenchUI
	get_root().add_child(crafting_ui)
	await process_frame
	await process_frame

	crafting_ui.open_start_menu_for(player, forge_controller, "Ranged Bow Anchor Bench")
	await process_frame
	await process_frame
	crafting_ui.start_menu_new_ranged_physical_button.emit_signal("pressed")
	await process_frame
	await process_frame

	var visible_entries: Array[Dictionary] = crafting_ui.visible_inventory_entries
	var preview: ForgeWorkspacePreview = crafting_ui.free_workspace_preview
	var marker_entries_count: int = 0
	var marker_entries_pinned_top: bool = true
	var seen_non_marker_entry: bool = false
	var a1_visible_index: int = -1
	var a2_visible_index: int = -1
	for index in range(visible_entries.size()):
		var entry: Dictionary = visible_entries[index]
		var is_builder_marker: bool = bool(entry.get("is_builder_marker", false))
		if is_builder_marker:
			marker_entries_count += 1
			if seen_non_marker_entry:
				marker_entries_pinned_top = false
		else:
			seen_non_marker_entry = true
		if entry.get("material_id", &"") == CraftedItemWIPScript.get_string_anchor_builder_marker_id(CraftedItemWIPScript.STRING_ANCHOR_PAIR_A, 1):
			a1_visible_index = index
		if entry.get("material_id", &"") == CraftedItemWIPScript.get_string_anchor_builder_marker_id(CraftedItemWIPScript.STRING_ANCHOR_PAIR_A, 2):
			a2_visible_index = index

	var default_selection_is_not_marker: bool = not CraftedItemWIPScript.is_builder_marker_material_id(crafting_ui.selected_material_variant_id)
	var default_armed_is_not_marker: bool = not CraftedItemWIPScript.is_builder_marker_material_id(crafting_ui.armed_material_variant_id)

	var normal_material_id: StringName = StringName()
	for entry: Dictionary in visible_entries:
		if bool(entry.get("is_builder_marker", false)):
			continue
		if int(entry.get("quantity", 0)) <= 0:
			continue
		normal_material_id = entry.get("material_id", &"")
		break

	var inventory_state: PlayerForgeInventoryState = player.get_forge_inventory_state()
	var normal_material_quantity_before_markers: int = inventory_state.get_quantity(normal_material_id)

	var a1_marker_id: StringName = CraftedItemWIPScript.get_string_anchor_builder_marker_id(CraftedItemWIPScript.STRING_ANCHOR_PAIR_A, 1)
	var a2_marker_id: StringName = CraftedItemWIPScript.get_string_anchor_builder_marker_id(CraftedItemWIPScript.STRING_ANCHOR_PAIR_A, 2)
	var marker_one_first_position: Vector3i = Vector3i(8, 12, forge_controller.get_active_layer_index())
	var marker_one_second_position: Vector3i = Vector3i(20, 18, forge_controller.get_active_layer_index())
	var marker_two_position: Vector3i = Vector3i(24, 30, forge_controller.get_active_layer_index())

	crafting_ui.selected_material_variant_id = a1_marker_id
	crafting_ui.armed_material_variant_id = a1_marker_id
	crafting_ui._place_material_cell(marker_one_first_position)
	await process_frame
	await process_frame

	var inventory_unchanged_after_first_marker: bool = inventory_state.get_quantity(normal_material_id) == normal_material_quantity_before_markers

	crafting_ui._place_material_cell(marker_one_second_position)
	await process_frame
	await process_frame

	crafting_ui.selected_material_variant_id = a2_marker_id
	crafting_ui.armed_material_variant_id = a2_marker_id
	crafting_ui._place_material_cell(marker_two_position)
	await process_frame
	await process_frame

	var marker_one_cell_count: int = _count_builder_markers_with_material_id(forge_controller.active_wip, a1_marker_id)
	var marker_two_cell_count: int = _count_builder_markers_with_material_id(forge_controller.active_wip, a2_marker_id)
	var marker_cells_in_layers_count: int = _count_layer_cells_with_material_id(forge_controller.active_wip, a1_marker_id) + _count_layer_cells_with_material_id(forge_controller.active_wip, a2_marker_id)
	var marker_one_relocated: bool = (
		marker_one_cell_count == 1
		and forge_controller.get_builder_marker_id_at(marker_one_first_position) == StringName()
		and forge_controller.get_builder_marker_id_at(marker_one_second_position) == a1_marker_id
	)
	var marker_two_placed: bool = marker_two_cell_count == 1 and forge_controller.get_builder_marker_id_at(marker_two_position) == a2_marker_id
	var marker_cells_live_outside_layers: bool = marker_cells_in_layers_count == 0
	var inventory_unchanged_after_second_marker: bool = inventory_state.get_quantity(normal_material_id) == normal_material_quantity_before_markers

	var authored_cells: Array[CellAtom] = CraftedItemWIPScript.collect_cells(forge_controller.active_wip, true)
	var bake_cells: Array[CellAtom] = CraftedItemWIPScript.collect_bake_cells(forge_controller.active_wip)
	var bake_cells_exclude_markers: bool = true
	for cell: CellAtom in bake_cells:
		if cell != null and CraftedItemWIPScript.is_builder_marker_material_id(cell.material_variant_id):
			bake_cells_exclude_markers = false
			break

	var material_lookup: Dictionary = forge_controller.build_default_material_lookup()
	var test_print: TestPrintInstance = forge_controller.spawn_test_print_from_active_wip(material_lookup)
	var test_print_display_excludes_markers: bool = true
	if test_print != null:
		for cell: CellAtom in test_print.display_cells:
			if cell != null and CraftedItemWIPScript.is_builder_marker_material_id(cell.material_variant_id):
				test_print_display_excludes_markers = false
				break

	var forge_service: ForgeService = forge_controller.get_forge_service()
	var segments: Array[SegmentAtom] = forge_service.build_segments(bake_cells, material_lookup)
	segments = forge_service.classify_joint_segments(segments, material_lookup)
	var bow_data: Dictionary = forge_service.build_bow_data(
		segments,
		material_lookup,
		forge_controller.active_wip.forge_intent if forge_controller.active_wip != null else &"",
		forge_controller.active_wip.equipment_context if forge_controller.active_wip != null else &"",
		authored_cells
	)
	var explicit_pair_detected: bool = (
		bow_data.get("string_anchor_source", &"") == &"explicit_authored_pair"
		and bow_data.get("string_anchor_pair_id", &"") == CraftedItemWIPScript.STRING_ANCHOR_PAIR_A
	)
	var string_rest_path_points: int = 0
	var string_rest_path_variant: Variant = bow_data.get("string_rest_path", [])
	if string_rest_path_variant is Array:
		string_rest_path_points = (string_rest_path_variant as Array).size()
	var string_draw_path_points: int = 0
	var string_draw_path_variant: Variant = bow_data.get("string_draw_path", [])
	if string_draw_path_variant is Array:
		string_draw_path_points = (string_draw_path_variant as Array).size()
	var string_draw_distance_positive: bool = float(bow_data.get("string_draw_distance_meters", 0.0)) > 0.0
	var preview_string_segment_a_visible: bool = (
		preview != null
		and preview.generated_string_segment_a != null
		and preview.generated_string_segment_a.visible
	)
	var preview_string_segment_b_visible: bool = (
		preview != null
		and preview.generated_string_segment_b != null
		and preview.generated_string_segment_b.visible
	)
	var preview_draw_string_segment_a_visible: bool = (
		preview != null
		and preview.generated_string_draw_segment_a != null
		and preview.generated_string_draw_segment_a.visible
	)
	var preview_draw_string_segment_b_visible: bool = (
		preview != null
		and preview.generated_string_draw_segment_b != null
		and preview.generated_string_draw_segment_b.visible
	)
	var preview_draw_pull_point_visible: bool = (
		preview != null
		and preview.generated_string_draw_pull_point != null
		and preview.generated_string_draw_pull_point.visible
	)
	var preview_builder_marker_count: int = preview.builder_marker_root.get_child_count() if preview != null and preview.builder_marker_root != null else 0
	var preview_string_visible: bool = preview_string_segment_a_visible and preview_string_segment_b_visible
	var preview_draw_string_visible: bool = (
		preview_draw_string_segment_a_visible
		and preview_draw_string_segment_b_visible
		and preview_draw_pull_point_visible
	)

	var lines: PackedStringArray = []
	lines.append("marker_entries_count=%s" % str(marker_entries_count))
	lines.append("marker_entries_pinned_top=%s" % str(marker_entries_pinned_top))
	lines.append("a1_visible_index=%d" % a1_visible_index)
	lines.append("a2_visible_index=%d" % a2_visible_index)
	lines.append("default_selection_is_not_marker=%s" % str(default_selection_is_not_marker))
	lines.append("default_armed_is_not_marker=%s" % str(default_armed_is_not_marker))
	lines.append("inventory_unchanged_after_first_marker=%s" % str(inventory_unchanged_after_first_marker))
	lines.append("marker_one_relocated=%s" % str(marker_one_relocated))
	lines.append("marker_two_placed=%s" % str(marker_two_placed))
	lines.append("marker_cells_live_outside_layers=%s" % str(marker_cells_live_outside_layers))
	lines.append("inventory_unchanged_after_second_marker=%s" % str(inventory_unchanged_after_second_marker))
	lines.append("bake_cells_exclude_markers=%s" % str(bake_cells_exclude_markers))
	lines.append("test_print_display_excludes_markers=%s" % str(test_print_display_excludes_markers))
	lines.append("explicit_pair_detected=%s" % str(explicit_pair_detected))
	lines.append("string_rest_path_points=%d" % string_rest_path_points)
	lines.append("string_draw_path_points=%d" % string_draw_path_points)
	lines.append("string_draw_distance_positive=%s" % str(string_draw_distance_positive))
	lines.append("preview_builder_marker_count=%d" % preview_builder_marker_count)
	lines.append("preview_string_segment_a_visible=%s" % str(preview_string_segment_a_visible))
	lines.append("preview_string_segment_b_visible=%s" % str(preview_string_segment_b_visible))
	lines.append("preview_string_visible=%s" % str(preview_string_visible))
	lines.append("preview_draw_string_visible=%s" % str(preview_draw_string_visible))

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/ranged_bow_string_anchor_markers_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _count_builder_markers_with_material_id(wip: CraftedItemWIP, material_id: StringName) -> int:
	var count: int = 0
	for cell: CellAtom in CraftedItemWIPScript.collect_builder_marker_cells(wip):
		if cell != null and cell.material_variant_id == material_id:
			count += 1
	return count

func _count_layer_cells_with_material_id(wip: CraftedItemWIP, material_id: StringName) -> int:
	var count: int = 0
	if wip == null:
		return count
	for layer_atom: LayerAtom in wip.layers:
		if layer_atom == null:
			continue
		for cell: CellAtom in layer_atom.cells:
			if cell != null and cell.material_variant_id == material_id:
				count += 1
	return count
