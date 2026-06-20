extends SceneTree

const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")

const OUTPUT_PATH := "C:/WORKSPACE/grip_occupancy_metadata_results.txt"
const LONG_GLAVE_PROJECT_NAME := "Long Glave  Animation  Test"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var controller: ForgeGridController = ForgeGridControllerScript.new()
	var forge_service: ForgeService = controller.get_forge_service()
	var material_lookup: Dictionary = controller.build_default_material_lookup()

	var centered_profile: BakedProfile = forge_service.bake_wip(_build_centered_pole_wip(), material_lookup)
	var front_heavy_profile: BakedProfile = forge_service.bake_wip(_build_front_heavy_sword_wip(), material_lookup)
	var long_glave_wip: CraftedItemWIP = _find_saved_wip_by_project_name(LONG_GLAVE_PROJECT_NAME)
	var long_glave_profile: BakedProfile = forge_service.bake_wip(long_glave_wip, material_lookup) if long_glave_wip != null else null

	var lines: PackedStringArray = []
	lines.append("centered_primary_grip_valid=%s" % str(centered_profile.primary_grip_valid if centered_profile != null else false))
	lines.append("centered_primary_grip_contact_percent=%s" % str(snapped(float(centered_profile.primary_grip_contact_percent if centered_profile != null else 0.0), 0.0001)))
	lines.append("centered_primary_grip_axis_ratio_from_span_start=%s" % str(snapped(float(centered_profile.primary_grip_axis_ratio_from_span_start if centered_profile != null else 0.0), 0.0001)))
	lines.append("centered_primary_grip_center_balance_valid=%s" % str(centered_profile.primary_grip_center_balance_valid if centered_profile != null else false))
	lines.append("centered_primary_grip_center_balance_offset_percent=%s" % str(snapped(float(centered_profile.primary_grip_center_balance_offset_percent if centered_profile != null else 0.0), 0.0001)))
	lines.append("centered_primary_grip_two_hand_eligible=%s" % str(centered_profile.primary_grip_two_hand_eligible if centered_profile != null else false))
	lines.append("centered_primary_grip_span_length_voxels=%d" % int(centered_profile.primary_grip_span_length_voxels if centered_profile != null else 0))
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
	lines.append("front_heavy_center_balance_rejected=%s" % str(front_heavy_profile != null and not front_heavy_profile.primary_grip_center_balance_valid))
	lines.append("long_glave_found=%s" % str(long_glave_wip != null))
	lines.append("long_glave_wip_id=%s" % String(long_glave_wip.wip_id if long_glave_wip != null else StringName()))
	lines.append("long_glave_primary_grip_valid=%s" % str(long_glave_profile != null and long_glave_profile.primary_grip_valid))
	lines.append("long_glave_validation_error=%s" % String(long_glave_profile.validation_error if long_glave_profile != null else ""))
	lines.append("long_glave_span_length_voxels=%d" % int(long_glave_profile.primary_grip_span_length_voxels if long_glave_profile != null else 0))
	lines.append("long_glave_center_balance_valid=%s" % str(long_glave_profile != null and long_glave_profile.primary_grip_center_balance_valid))
	lines.append("long_glave_two_hand_eligible=%s" % str(long_glave_profile != null and long_glave_profile.primary_grip_two_hand_eligible))
	lines.append("long_glave_contact_percent=%s" % str(snapped(float(long_glave_profile.primary_grip_contact_percent if long_glave_profile != null else 0.0), 0.0001)))
	var long_glave_optional_check_passed: bool = (
		long_glave_wip == null
		or (
			long_glave_profile != null
			and long_glave_profile.primary_grip_valid
			and long_glave_profile.primary_grip_two_hand_eligible
			and long_glave_profile.primary_grip_span_length_voxels >= 26
		)
	)
	lines.append("long_glave_optional_check_passed=%s" % str(long_glave_optional_check_passed))
	var all_checks_passed: bool = (
		centered_profile != null
		and centered_profile.primary_grip_valid
		and centered_profile.primary_grip_center_balance_valid
		and centered_profile.primary_grip_two_hand_eligible
		and centered_profile.primary_grip_two_hand_negative_limit < 0.0
		and centered_profile.primary_grip_two_hand_positive_limit > 0.0
		and front_heavy_profile != null
		and front_heavy_profile.primary_grip_valid
		and front_heavy_profile.primary_grip_contact_percent > 0.75
		and not front_heavy_profile.primary_grip_center_balance_valid
		and long_glave_optional_check_passed
	)
	lines.append("all_checks_passed=%s" % str(all_checks_passed))

	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	controller.free()
	quit(0 if all_checks_passed else 1)

func _build_centered_pole_wip() -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = &"verify_centered_pole_grip_metadata"
	wip.forge_project_name = "Verify Centered Pole Grip Metadata"
	wip.creator_id = &"verify"
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"

	var layer_map: Dictionary = {}
	for x: int in range(36, 66):
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
	for x: int in range(32, 58):
		for y: int in range(24, 27):
			for z: int in range(18, 20):
				_add_cell(layer_map, Vector3i(x, y, z), &"mat_wood_gray")

	for x: int in range(58, 65):
		for y: int in range(23, 28):
			for z: int in range(17, 21):
				_add_cell(layer_map, Vector3i(x, y, z), &"mat_iron_gray")

	var ordered_layers: Array = layer_map.keys()
	ordered_layers.sort()
	for layer_index_value in ordered_layers:
		wip.layers.append(layer_map[layer_index_value])
	return wip

func _find_saved_wip_by_project_name(project_name: String) -> CraftedItemWIP:
	var library_state: PlayerForgeWipLibraryState = _load_player_wip_library_state()
	if library_state == null:
		return null
	for saved_wip: CraftedItemWIP in library_state.get_saved_wips():
		if saved_wip == null:
			continue
		if saved_wip.forge_project_name == project_name:
			return saved_wip
	return null

func _load_player_wip_library_state() -> PlayerForgeWipLibraryState:
	var appdata_path: String = OS.get_environment("APPDATA")
	if not appdata_path.is_empty():
		var absolute_save_path: String = appdata_path.path_join("Godot/app_userdata/The Will-Gamefiles/forge/player_wip_library_state.tres")
		if FileAccess.file_exists(absolute_save_path):
			return PlayerForgeWipLibraryStateScript.load_or_create(absolute_save_path) as PlayerForgeWipLibraryState
	return PlayerForgeWipLibraryStateScript.load_or_create() as PlayerForgeWipLibraryState

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
