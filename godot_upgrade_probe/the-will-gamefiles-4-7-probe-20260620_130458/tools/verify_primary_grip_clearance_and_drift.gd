extends SceneTree

const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")

const OUTPUT_PATH := "c:/WORKSPACE/primary_grip_clearance_and_drift_results.txt"
const WOOD_MATERIAL_ID := &"mat_wood_gray"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var controller: ForgeGridController = ForgeGridControllerScript.new()
	get_root().add_child(controller)
	await process_frame
	await process_frame

	var forge_service: ForgeService = controller.get_forge_service()
	var material_lookup: Dictionary = controller.build_default_material_lookup()
	var lines: PackedStringArray = []

	var straight_melee_wip: CraftedItemWIP = _build_shifted_handle_wip(
		&"verify_straight_melee_grip",
		"Verify Straight Melee Grip",
		CraftedItemWIP.BUILDER_PATH_MELEE,
		20,
		func(_slice_index: int) -> Vector2i:
			return Vector2i(4, 4)
	)
	var straight_melee_profile: BakedProfile = forge_service.bake_wip(straight_melee_wip, material_lookup)
	lines.append("straight_melee_primary_grip_valid=%s" % str(straight_melee_profile != null and straight_melee_profile.primary_grip_valid))
	lines.append("straight_melee_span_length=%d" % int(straight_melee_profile.primary_grip_span_length_voxels if straight_melee_profile != null else 0))
	lines.append("straight_melee_two_hand_eligible=%s" % str(straight_melee_profile != null and straight_melee_profile.primary_grip_two_hand_eligible))

	var long_magic_wip: CraftedItemWIP = _build_shifted_handle_wip(
		&"verify_long_magic_grip",
		"Verify Long Magic Grip",
		CraftedItemWIP.BUILDER_PATH_MAGIC,
		26,
		func(_slice_index: int) -> Vector2i:
			return Vector2i(4, 4)
	)
	var long_magic_profile: BakedProfile = forge_service.bake_wip(long_magic_wip, material_lookup)
	lines.append("long_magic_primary_grip_valid=%s" % str(long_magic_profile != null and long_magic_profile.primary_grip_valid))
	lines.append("long_magic_two_hand_eligible=%s" % str(long_magic_profile != null and long_magic_profile.primary_grip_two_hand_eligible))

	var long_shield_wip: CraftedItemWIP = _build_shifted_handle_wip(
		&"verify_long_shield_grip",
		"Verify Long Shield Grip",
		CraftedItemWIP.BUILDER_PATH_SHIELD,
		26,
		func(_slice_index: int) -> Vector2i:
			return Vector2i(4, 4)
	)
	var long_shield_profile: BakedProfile = forge_service.bake_wip(long_shield_wip, material_lookup)
	lines.append("long_shield_primary_grip_valid=%s" % str(long_shield_profile != null and long_shield_profile.primary_grip_valid))
	lines.append("long_shield_two_hand_eligible=%s" % str(long_shield_profile != null and long_shield_profile.primary_grip_two_hand_eligible))

	var diagonal_melee_wip: CraftedItemWIP = _build_shifted_handle_wip(
		&"verify_diagonal_melee_grip",
		"Verify Diagonal Melee Grip",
		CraftedItemWIP.BUILDER_PATH_MELEE,
		20,
		func(slice_index: int) -> Vector2i:
			return Vector2i(4 + int(slice_index / 4), 4)
	)
	var diagonal_melee_profile: BakedProfile = forge_service.bake_wip(diagonal_melee_wip, material_lookup)
	lines.append("diagonal_melee_primary_grip_valid=%s" % str(diagonal_melee_profile != null and diagonal_melee_profile.primary_grip_valid))
	lines.append("diagonal_melee_span_length=%d" % int(diagonal_melee_profile.primary_grip_span_length_voxels if diagonal_melee_profile != null else 0))

	var clearanced_shield_wip: CraftedItemWIP = _build_clearanced_shield_handle_wip(
		&"verify_clearanced_shield_handle",
		"Verify Clearanced Shield Handle",
		true
	)
	var clearanced_shield_profile: BakedProfile = forge_service.bake_wip(clearanced_shield_wip, material_lookup)
	lines.append("clearanced_shield_primary_grip_valid=%s" % str(clearanced_shield_profile != null and clearanced_shield_profile.primary_grip_valid))

	var blocked_shield_wip: CraftedItemWIP = _build_clearanced_shield_handle_wip(
		&"verify_blocked_shield_handle",
		"Verify Blocked Shield Handle",
		false
	)
	var blocked_shield_profile: BakedProfile = forge_service.bake_wip(blocked_shield_wip, material_lookup)
	var blocked_cells: Array[CellAtom] = CraftedItemWIPScript.collect_bake_cells(blocked_shield_wip)
	var blocked_segments: Array[SegmentAtom] = forge_service.build_segments(blocked_cells, material_lookup)
	var blocked_anchors: Array[AnchorAtom] = forge_service.build_anchors(blocked_segments, material_lookup)
	lines.append("blocked_shield_primary_grip_valid=%s" % str(blocked_shield_profile != null and blocked_shield_profile.primary_grip_valid))
	lines.append("blocked_shield_validation_error=%s" % String(blocked_shield_profile.validation_error if blocked_shield_profile != null else ""))
	lines.append("blocked_shield_anchor_count=%d" % blocked_anchors.size())
	if not blocked_segments.is_empty():
		var blocked_segment: SegmentAtom = blocked_segments[0]
		lines.append("blocked_shield_segment_major_axis=%s" % str(blocked_segment.major_axis))
		lines.append("blocked_shield_segment_width=%d" % blocked_segment.cross_width_voxels)
		lines.append("blocked_shield_segment_thickness=%d" % blocked_segment.cross_thickness_voxels)

	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	controller.queue_free()
	quit()

func _build_shifted_handle_wip(
	wip_id: StringName,
	project_name: String,
	builder_path_id: StringName,
	length_slices: int,
	offset_resolver: Callable
) -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = wip_id
	wip.forge_project_name = project_name
	wip.creator_id = &"test"
	CraftedItemWIPScript.apply_builder_path_defaults(wip, builder_path_id)

	var layer_map: Dictionary = {}
	for slice_index: int in range(length_slices):
		var offset: Variant = offset_resolver.call(slice_index)
		var yz_offset: Vector2i = offset if offset is Vector2i else Vector2i(4, 4)
		for y in range(yz_offset.x, yz_offset.x + 2):
			for z in range(yz_offset.y, yz_offset.y + 3):
				_add_cell(layer_map, Vector3i(slice_index, y, z), WOOD_MATERIAL_ID)

	var ordered_layers: Array = layer_map.keys()
	ordered_layers.sort()
	for layer_index_value in ordered_layers:
		wip.layers.append(layer_map[layer_index_value])
	return wip

func _build_clearanced_shield_handle_wip(
	wip_id: StringName,
	project_name: String,
	with_clearance: bool
) -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = wip_id
	wip.forge_project_name = project_name
	wip.creator_id = &"test"
	CraftedItemWIPScript.apply_builder_path_defaults(wip, CraftedItemWIP.BUILDER_PATH_SHIELD)

	var layer_map: Dictionary = {}
	for slice_index: int in range(26):
		for y in range(4, 6):
			for z in range(4, 7):
				_add_cell(layer_map, Vector3i(slice_index, y, z), WOOD_MATERIAL_ID)
		var plate_min: int = 2 if with_clearance else 3
		var plate_max_y: int = 8 if with_clearance else 7
		var plate_max_z: int = 9 if with_clearance else 8
		for y in range(plate_min, plate_max_y):
			for z in range(plate_min, plate_max_z):
				if with_clearance:
					if y >= 3 and y <= 6 and z >= 3 and z <= 7:
						continue
				elif y >= 4 and y <= 5 and z >= 4 and z <= 6:
					continue
				_add_cell(layer_map, Vector3i(slice_index, y, z), WOOD_MATERIAL_ID)

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
