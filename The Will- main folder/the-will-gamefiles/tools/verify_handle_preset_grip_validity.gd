extends SceneTree

const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const PrimaryGripSliceProfileLibraryScript = preload("res://core/defs/primary_grip_slice_profile_library.gd")

const OUTPUT_PATH := "c:/WORKSPACE/handle_preset_grip_validity_results.txt"
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
	var all_valid: bool = true

	for preset_def: Dictionary in PrimaryGripSliceProfileLibraryScript.get_preset_defs():
		var preset_id: StringName = preset_def.get("preset_id", StringName())
		var preset_label: String = String(preset_def.get("label", "Handle"))
		var preset_rows: Array[String] = []
		for row_variant: Variant in preset_def.get("rows", []):
			preset_rows.append(String(row_variant))
		var wip: CraftedItemWIP = _build_handle_profile_wip(
			preset_id,
			"Verify %s Grip" % preset_label,
			preset_rows,
			20
		)
		var profile: BakedProfile = forge_service.bake_wip(wip, material_lookup)
		var is_valid: bool = profile != null and profile.primary_grip_valid
		all_valid = all_valid and is_valid
		lines.append("%s_valid=%s" % [String(preset_id), str(is_valid)])
		lines.append("%s_span_length=%d" % [String(preset_id), int(profile.primary_grip_span_length_voxels if profile != null else 0)])
		lines.append("%s_error=%s" % [String(preset_id), String(profile.validation_error if profile != null else "")])

	lines.append("all_handle_presets_valid=%s" % str(all_valid))

	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	controller.queue_free()
	quit()

func _build_handle_profile_wip(
	wip_id: StringName,
	project_name: String,
	rows: Array[String],
	length_slices: int
) -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = wip_id
	wip.forge_project_name = project_name
	wip.creator_id = &"test"
	CraftedItemWIPScript.apply_builder_path_defaults(wip, CraftedItemWIP.BUILDER_PATH_MELEE)

	var layer_map: Dictionary = {}
	for slice_index: int in range(length_slices):
		for row_index: int in range(rows.size()):
			var row_text: String = rows[row_index]
			for column_index: int in range(row_text.length()):
				if row_text.substr(column_index, 1) != "1":
					continue
				_add_cell(layer_map, Vector3i(slice_index, 4 + column_index, 4 + row_index), WOOD_MATERIAL_ID)

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
