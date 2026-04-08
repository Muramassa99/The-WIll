extends SceneTree

const PlayerScene = preload("res://scenes/player/player_character.tscn")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_grip_hold_layout_results.txt"
const TEMP_STATE_DIR := "C:/WORKSPACE/test_artifacts"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var player_root: Node = PlayerScene.instantiate()
	root.add_child(player_root)
	await process_frame
	await process_frame

	var player = player_root as PlayerController3D
	var wip_library = PlayerForgeWipLibraryStateScript.new()
	wip_library.save_file_path = "%s/verify_player_grip_hold_layout_state.tres" % TEMP_STATE_DIR
	player.forge_wip_library_state = wip_library

	var centered_pole: CraftedItemWIP = wip_library.save_wip(_build_centered_pole_wip())
	var front_heavy_staff: CraftedItemWIP = wip_library.save_wip(_build_front_heavy_staff_wip())

	var centered_layout: Dictionary = player.preview_saved_wip_grip_hold_layout(centered_pole.wip_id, &"hand_right")
	var front_heavy_layout: Dictionary = player.preview_saved_wip_grip_hold_layout(front_heavy_staff.wip_id, &"hand_right")
	var rig: PlayerHumanoidRig = player.humanoid_rig as PlayerHumanoidRig if player != null else null
	var character_span_meters: float = rig.get_max_model_arm_reach_combat_meters() if rig != null else 0.0

	var lines: PackedStringArray = []
	lines.append("character_two_hand_span_meters=%s" % str(snappedf(character_span_meters, 0.001)))
	lines.append("centered_valid=%s" % str(bool(centered_layout.get("valid", false))))
	lines.append("centered_two_hand_weapon_eligible=%s" % str(bool(centered_layout.get("two_hand_weapon_eligible", false))))
	lines.append("centered_two_hand_character_eligible=%s" % str(bool(centered_layout.get("two_hand_character_eligible", false))))
	lines.append("centered_effective_two_hand_span_meters=%s" % str(snappedf(float(centered_layout.get("effective_two_hand_span_meters", 0.0)), 0.001)))
	lines.append("centered_dominant_signed_ratio=%s" % str(snappedf(float(centered_layout.get("dominant_hand_signed_ratio", 0.0)), 0.001)))
	lines.append("centered_support_signed_ratio=%s" % str(snappedf(float(centered_layout.get("support_hand_signed_ratio", 0.0)), 0.001)))
	lines.append("centered_span_clamped_to_character=%s" % str(
		bool(centered_layout.get("two_hand_character_eligible", false))
		and is_equal_approx(float(centered_layout.get("effective_two_hand_span_meters", 0.0)), character_span_meters)
	))
	lines.append("front_heavy_valid=%s" % str(bool(front_heavy_layout.get("valid", false))))
	lines.append("front_heavy_center_balance_valid=%s" % str(bool(front_heavy_layout.get("center_balance_valid", false))))
	lines.append("front_heavy_two_hand_weapon_eligible=%s" % str(bool(front_heavy_layout.get("two_hand_weapon_eligible", false))))
	lines.append("front_heavy_two_hand_character_eligible=%s" % str(bool(front_heavy_layout.get("two_hand_character_eligible", false))))
	lines.append("front_heavy_dominant_contact_percent=%s" % str(snappedf(float(front_heavy_layout.get("dominant_hand_contact_percent", 0.0)), 0.001)))
	lines.append("front_heavy_support_contact_percent=%s" % str(snappedf(float(front_heavy_layout.get("support_hand_contact_percent", 0.0)), 0.001)))
	lines.append("front_heavy_support_extends_farther_than_dominant=%s" % str(
		float(front_heavy_layout.get("support_hand_contact_percent", 0.0)) < float(front_heavy_layout.get("dominant_hand_contact_percent", 0.0))
	))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _build_centered_pole_wip() -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = &"verify_player_centered_pole_layout"
	wip.forge_project_name = "Verify Player Centered Pole Layout"
	wip.creator_id = &"verify"
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"

	var layer_map: Dictionary = {}
	for x: int in range(30, 110):
		for y: int in range(24, 27):
			for z: int in range(18, 20):
				_add_cell(layer_map, Vector3i(x, y, z), &"mat_wood_gray")

	var ordered_layers: Array = layer_map.keys()
	ordered_layers.sort()
	for layer_index_value in ordered_layers:
		wip.layers.append(layer_map[layer_index_value])
	return wip

func _build_front_heavy_staff_wip() -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = &"verify_player_front_heavy_layout"
	wip.forge_project_name = "Verify Player Front Heavy Layout"
	wip.creator_id = &"verify"
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"

	var layer_map: Dictionary = {}
	for x: int in range(30, 90):
		for y: int in range(24, 27):
			for z: int in range(18, 20):
				_add_cell(layer_map, Vector3i(x, y, z), &"mat_wood_gray")

	for x: int in range(90, 106):
		for y: int in range(21, 30):
			for z: int in range(16, 22):
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
