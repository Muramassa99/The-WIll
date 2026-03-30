extends SceneTree

const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")

const OUTPUT_PATH := "c:/WORKSPACE/anchor_area_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var controller: ForgeGridController = ForgeGridControllerScript.new()
	var forge_service: ForgeService = controller.get_forge_service()
	var material_lookup: Dictionary = controller.build_default_material_lookup()
	var test_wip: CraftedItemWIP = _build_connected_sword_wip()
	var cells: Array[CellAtom] = _collect_cells(test_wip)
	var segments: Array[SegmentAtom] = forge_service.build_segments(cells, material_lookup)
	segments = forge_service.classify_joint_segments(segments, material_lookup)
	var anchors: Array[AnchorAtom] = forge_service.build_anchors(segments, material_lookup)
	var profile: BakedProfile = forge_service.bake_wip(test_wip, material_lookup)

	var lines: PackedStringArray = []
	lines.append("test_wip_id=%s" % String(test_wip.wip_id))
	lines.append("cell_count=%d" % cells.size())
	lines.append("segment_count=%d" % segments.size())
	lines.append("anchor_count=%d" % anchors.size())
	lines.append("primary_grip_valid=%s" % str(profile.primary_grip_valid if profile != null else false))
	lines.append("validation_error=%s" % String(profile.validation_error if profile != null else ""))
	lines.append("primary_grip_span_length_voxels=%d" % int(profile.primary_grip_span_length_voxels if profile != null else 0))
	lines.append("primary_grip_contact_position=%s" % str(profile.primary_grip_contact_position if profile != null else Vector3.ZERO))
	lines.append("primary_grip_span_start=%s" % str(profile.primary_grip_span_start if profile != null else Vector3.ZERO))
	lines.append("primary_grip_span_end=%s" % str(profile.primary_grip_span_end if profile != null else Vector3.ZERO))
	lines.append("balance_score=%s" % str(profile.balance_score if profile != null else 0.0))
	lines.append("reach=%s" % str(profile.reach if profile != null else 0.0))

	if not anchors.is_empty():
		var primary_grip: AnchorAtom = anchors[0]
		lines.append("first_anchor_id=%s" % String(primary_grip.anchor_id))
		lines.append("first_anchor_span_length=%d" % primary_grip.span_length)
		lines.append("first_anchor_span_start_index=%d" % primary_grip.span_start_index)
		lines.append("first_anchor_span_end_index=%d" % primary_grip.span_end_index)
		lines.append("first_anchor_span_ratio=%s" % str(primary_grip.span_anchor_material_ratio))

	if not segments.is_empty():
		var segment: SegmentAtom = segments[0]
		lines.append("segment_major_axis=%s" % str(segment.major_axis))
		lines.append("segment_cross_width=%d" % segment.cross_width_voxels)
		lines.append("segment_cross_thickness=%d" % segment.cross_thickness_voxels)
		lines.append("segment_anchor_material_ratio=%s" % str(segment.anchor_material_ratio))

	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	controller.free()
	quit()

func _build_connected_sword_wip() -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = &"verify_anchor_area_connected_sword"
	wip.forge_project_name = "Verify Anchor Area Connected Sword"
	wip.creator_id = &"test"
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"

	var layer_map: Dictionary = {}

	for x: int in range(74, 86):
		for y: int in range(38, 41):
			for z: int in range(20, 22):
				_add_cell(layer_map, Vector3i(x, y, z), &"mat_wood_gray")

	for x: int in range(86, 98):
		for y: int in range(36, 43):
			for z: int in range(19, 24):
				_add_cell(layer_map, Vector3i(x, y, z), &"mat_iron_gray")

	var ordered_layers: Array = layer_map.keys()
	ordered_layers.sort()
	for layer_index_value in ordered_layers:
		wip.layers.append(layer_map[layer_index_value])
	return wip

func _add_cell(layer_map: Dictionary, grid_position: Vector3i, material_variant_id: StringName) -> void:
	if not layer_map.has(grid_position.z):
		var layer: LayerAtom = LayerAtom.new()
		layer.layer_index = grid_position.z
		layer.cells = []
		layer_map[grid_position.z] = layer
	var cell: CellAtom = CellAtom.new()
	cell.grid_position = grid_position
	cell.layer_index = grid_position.z
	cell.material_variant_id = material_variant_id
	var target_layer: LayerAtom = layer_map[grid_position.z]
	target_layer.cells.append(cell)

func _collect_cells(wip: CraftedItemWIP) -> Array[CellAtom]:
	var cells: Array[CellAtom] = []
	for layer: LayerAtom in wip.layers:
		if layer == null:
			continue
		for cell: CellAtom in layer.cells:
			if cell == null:
				continue
			cells.append(cell)
	return cells
