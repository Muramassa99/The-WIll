extends SceneTree

const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")

const OUTPUT_PATH := "c:/WORKSPACE/branch_grip_validity_results.txt"
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

	var shield_wip: CraftedItemWIP = _build_prismatic_branch_wip(
		&"verify_shield_grip_valid",
		"Verify Shield Grip Valid",
		CraftedItemWIP.BUILDER_PATH_SHIELD,
		Vector3i(26, 2, 3)
	)
	var shield_profile: BakedProfile = forge_service.bake_wip(shield_wip, material_lookup)
	lines.append("shield_primary_grip_valid=%s" % str(shield_profile != null and shield_profile.primary_grip_valid))
	lines.append("shield_validation_error=%s" % String(shield_profile.validation_error if shield_profile != null else ""))
	lines.append("shield_two_hand_eligible=%s" % str(shield_profile != null and shield_profile.primary_grip_two_hand_eligible))

	var shield_invalid_wip: CraftedItemWIP = _build_prismatic_branch_wip(
		&"verify_shield_grip_invalid",
		"Verify Shield Grip Invalid",
		CraftedItemWIP.BUILDER_PATH_SHIELD,
		Vector3i(20, 5, 1)
	)
	var shield_invalid_profile: BakedProfile = forge_service.bake_wip(shield_invalid_wip, material_lookup)
	lines.append("shield_invalid_primary_grip_valid=%s" % str(shield_invalid_profile != null and shield_invalid_profile.primary_grip_valid))
	lines.append("shield_invalid_validation_error=%s" % String(shield_invalid_profile.validation_error if shield_invalid_profile != null else ""))

	var magic_wip: CraftedItemWIP = _build_prismatic_branch_wip(
		&"verify_magic_grip_valid",
		"Verify Magic Grip Valid",
		CraftedItemWIP.BUILDER_PATH_MAGIC,
		Vector3i(26, 2, 3)
	)
	var magic_profile: BakedProfile = forge_service.bake_wip(magic_wip, material_lookup)
	lines.append("magic_primary_grip_valid=%s" % str(magic_profile != null and magic_profile.primary_grip_valid))
	lines.append("magic_validation_error=%s" % String(magic_profile.validation_error if magic_profile != null else ""))
	lines.append("magic_two_hand_eligible=%s" % str(magic_profile != null and magic_profile.primary_grip_two_hand_eligible))

	var magic_invalid_wip: CraftedItemWIP = _build_prismatic_branch_wip(
		&"verify_magic_grip_invalid",
		"Verify Magic Grip Invalid",
		CraftedItemWIP.BUILDER_PATH_MAGIC,
		Vector3i(20, 5, 1)
	)
	var magic_invalid_profile: BakedProfile = forge_service.bake_wip(magic_invalid_wip, material_lookup)
	lines.append("magic_invalid_primary_grip_valid=%s" % str(magic_invalid_profile != null and magic_invalid_profile.primary_grip_valid))
	lines.append("magic_invalid_validation_error=%s" % String(magic_invalid_profile.validation_error if magic_invalid_profile != null else ""))

	var generic_ranged_wip: CraftedItemWIP = _build_prismatic_branch_wip(
		&"verify_ranged_grip_only_valid",
		"Verify Ranged Grip Only Valid",
		CraftedItemWIP.BUILDER_PATH_RANGED_PHYSICAL,
		Vector3i(26, 2, 3)
	)
	var generic_ranged_profile: BakedProfile = forge_service.bake_wip(generic_ranged_wip, material_lookup)
	var generic_ranged_cells: Array[CellAtom] = CraftedItemWIPScript.collect_bake_cells(generic_ranged_wip)
	var generic_ranged_segments: Array[SegmentAtom] = forge_service.build_segments(generic_ranged_cells, material_lookup)
	generic_ranged_segments = forge_service.classify_joint_segments(generic_ranged_segments, material_lookup)
	var generic_ranged_bow_data: Dictionary = forge_service.build_bow_data(
		generic_ranged_segments,
		material_lookup,
		generic_ranged_wip.forge_intent,
		generic_ranged_wip.equipment_context,
		CraftedItemWIPScript.collect_cells(generic_ranged_wip, true)
	)
	lines.append("ranged_grip_only_primary_grip_valid=%s" % str(generic_ranged_profile != null and generic_ranged_profile.primary_grip_valid))
	lines.append("ranged_grip_only_two_hand_eligible=%s" % str(generic_ranged_profile != null and generic_ranged_profile.primary_grip_two_hand_eligible))
	lines.append("ranged_grip_only_bow_valid=%s" % str(bool(generic_ranged_bow_data.get("bow_valid", false))))
	lines.append("ranged_grip_only_bow_error=%s" % String(generic_ranged_bow_data.get("validation_error", &"")))

	var bow_sample_wip: CraftedItemWIP = controller.load_new_blank_wip_for_builder_path(
		"Verify Blank Bow Branch",
		CraftedItemWIP.BUILDER_PATH_RANGED_PHYSICAL,
		CraftedItemWIP.BUILDER_COMPONENT_BOW
	)
	var bow_profile: BakedProfile = forge_service.bake_wip(bow_sample_wip, material_lookup)
	var bow_cells: Array[CellAtom] = CraftedItemWIPScript.collect_bake_cells(bow_sample_wip)
	var bow_segments: Array[SegmentAtom] = forge_service.build_segments(bow_cells, material_lookup)
	bow_segments = forge_service.classify_joint_segments(bow_segments, material_lookup)
	var bow_data: Dictionary = forge_service.build_bow_data(
		bow_segments,
		material_lookup,
		bow_sample_wip.forge_intent,
		bow_sample_wip.equipment_context,
		CraftedItemWIPScript.collect_cells(bow_sample_wip, true)
	)
	lines.append("bow_primary_grip_valid=%s" % str(bow_profile != null and bow_profile.primary_grip_valid))
	lines.append("bow_validation_error=%s" % String(bow_profile.validation_error if bow_profile != null else ""))
	lines.append("bow_two_hand_eligible=%s" % str(bow_profile != null and bow_profile.primary_grip_two_hand_eligible))
	lines.append("bow_valid=%s" % str(bool(bow_data.get("bow_valid", false))))
	lines.append("bow_error=%s" % String(bow_data.get("validation_error", &"")))

	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	controller.queue_free()
	quit()

func _build_prismatic_branch_wip(
	wip_id: StringName,
	project_name: String,
	builder_path_id: StringName,
	size_voxels: Vector3i
) -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = wip_id
	wip.forge_project_name = project_name
	wip.creator_id = &"test"
	CraftedItemWIPScript.apply_builder_path_defaults(wip, builder_path_id)

	var layer_map: Dictionary = {}
	for x: int in range(size_voxels.x):
		for y: int in range(size_voxels.y):
			for z: int in range(size_voxels.z):
				_add_cell(layer_map, Vector3i(x, y, z), WOOD_MATERIAL_ID)

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
