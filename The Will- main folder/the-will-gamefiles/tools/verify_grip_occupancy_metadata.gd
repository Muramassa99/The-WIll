extends SceneTree

const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")

const OUTPUT_PATH := "C:/WORKSPACE/grip_occupancy_metadata_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var controller: ForgeGridController = ForgeGridControllerScript.new()
	var forge_service: ForgeService = controller.get_forge_service()
	var material_lookup: Dictionary = controller.build_default_material_lookup()

	var centered_profile: BakedProfile = forge_service.bake_wip(_build_centered_pole_wip(), material_lookup)
	var front_heavy_profile: BakedProfile = forge_service.bake_wip(_build_front_heavy_sword_wip(), material_lookup)

	var lines: PackedStringArray = []
	lines.append("centered_primary_grip_valid=%s" % str(centered_profile.primary_grip_valid if centered_profile != null else false))
	lines.append("centered_primary_grip_contact_percent=%s" % str(snapped(float(centered_profile.primary_grip_contact_percent if centered_profile != null else 0.0), 0.0001)))
	lines.append("centered_primary_grip_axis_ratio_from_span_start=%s" % str(snapped(float(centered_profile.primary_grip_axis_ratio_from_span_start if centered_profile != null else 0.0), 0.0001)))
	lines.append("centered_primary_grip_center_balance_valid=%s" % str(centered_profile.primary_grip_center_balance_valid if centered_profile != null else false))
	lines.append("centered_primary_grip_center_balance_offset_percent=%s" % str(snapped(float(centered_profile.primary_grip_center_balance_offset_percent if centered_profile != null else 0.0), 0.0001)))
	lines.append("centered_primary_grip_two_hand_eligible=%s" % str(centered_profile.primary_grip_two_hand_eligible if centered_profile != null else false))
	lines.append("centered_primary_grip_two_hand_negative_limit=%s" % str(snapped(float(centered_profile.primary_grip_two_hand_negative_limit if centered_profile != null else 0.0), 0.0001)))
	lines.append("centered_primary_grip_two_hand_positive_limit=%s" % str(snapped(float(centered_profile.primary_grip_two_hand_positive_limit if centered_profile != null else 0.0), 0.0001)))
	lines.append("centered_balanced_signed_limits_match_rule=%s" % str(
		centered_profile != null
		and centered_profile.primary_grip_center_balance_valid
		and is_equal_approx(centered_profile.primary_grip_two_hand_negative_limit, -0.8)
		and is_equal_approx(centered_profile.primary_grip_two_hand_positive_limit, 0.8)
	))

	lines.append("front_heavy_primary_grip_valid=%s" % str(front_heavy_profile.primary_grip_valid if front_heavy_profile != null else false))
	lines.append("front_heavy_primary_grip_contact_percent=%s" % str(snapped(float(front_heavy_profile.primary_grip_contact_percent if front_heavy_profile != null else 0.0), 0.0001)))
	lines.append("front_heavy_primary_grip_center_balance_valid=%s" % str(front_heavy_profile.primary_grip_center_balance_valid if front_heavy_profile != null else false))
	lines.append("front_heavy_primary_grip_two_hand_eligible=%s" % str(front_heavy_profile.primary_grip_two_hand_eligible if front_heavy_profile != null else false))
	lines.append("front_heavy_contact_prefers_com_side=%s" % str(front_heavy_profile != null and front_heavy_profile.primary_grip_contact_percent > 0.75))

	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	controller.free()
	quit()

func _build_centered_pole_wip() -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = &"verify_centered_pole_grip_metadata"
	wip.forge_project_name = "Verify Centered Pole Grip Metadata"
	wip.creator_id = &"verify"
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"

	var layer_map: Dictionary = {}
	for x: int in range(40, 62):
		for y: int in range(24, 27):
			for z: int in range(18, 20):
				_add_cell(layer_map, Vector3i(x, y, z), &"mat_wood_gray")

	var ordered_layers: Array = layer_map.keys()
	ordered_layers.sort()
	for layer_index_value in ordered_layers:
		wip.layers.append(layer_map[layer_index_value])
	return wip

func _build_front_heavy_sword_wip() -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = &"verify_front_heavy_grip_metadata"
	wip.forge_project_name = "Verify Front Heavy Grip Metadata"
	wip.creator_id = &"verify"
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"

	var layer_map: Dictionary = {}
	for x: int in range(40, 52):
		for y: int in range(24, 27):
			for z: int in range(18, 20):
				_add_cell(layer_map, Vector3i(x, y, z), &"mat_wood_gray")

	for x: int in range(52, 65):
		for y: int in range(22, 29):
			for z: int in range(17, 22):
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
