extends SceneTree

const PlayerBodyInventoryStateScript = preload("res://core/models/player_body_inventory_state.gd")
const PlayerPersonalStorageStateScript = preload("res://core/models/player_personal_storage_state.gd")
const PlayerEquipmentStateScript = preload("res://core/models/player_equipment_state.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/left_grip_correction_axis_diagnosis.txt"
const TEMP_STATE_DIR := "C:/WORKSPACE/test_artifacts"
const AXIS_CANDIDATES := {
	"right": Vector3.RIGHT,
	"up": Vector3.UP,
	"forward": Vector3.FORWARD
}

func _init() -> void:
	call_deferred("_run_diagnosis")

func _run_diagnosis() -> void:
	var player_scene: PackedScene = load("res://scenes/player/player_character.tscn") as PackedScene
	var player_root: Node = player_scene.instantiate()
	root.add_child(player_root)
	await process_frame
	await process_frame

	var player := player_root as PlayerController3D
	var body_state = PlayerBodyInventoryStateScript.new()
	body_state.save_file_path = "%s/diag_left_axis_body_inventory_state.tres" % TEMP_STATE_DIR
	var personal_state = PlayerPersonalStorageStateScript.new()
	personal_state.save_file_path = "%s/diag_left_axis_personal_storage_state.tres" % TEMP_STATE_DIR
	var equipment_state = PlayerEquipmentStateScript.new()
	equipment_state.save_file_path = "%s/diag_left_axis_equipment_state.tres" % TEMP_STATE_DIR
	var wip_library = PlayerForgeWipLibraryStateScript.new()
	wip_library.save_file_path = "%s/diag_left_axis_wip_library_state.tres" % TEMP_STATE_DIR

	player.body_inventory_state = body_state
	player.personal_storage_state = personal_state
	player.equipment_state = equipment_state
	player.forge_wip_library_state = wip_library
	player._sync_equipped_test_meshes()

	var normal_wip: CraftedItemWIP = wip_library.save_wip(_build_valid_test_wip(&"diag_axis_normal", CraftedItemWIP.GRIP_NORMAL))
	var reverse_wip: CraftedItemWIP = wip_library.save_wip(_build_valid_test_wip(&"diag_axis_reverse", CraftedItemWIP.GRIP_REVERSE))

	var right_normal: Dictionary = await _equip_and_measure(player, normal_wip.wip_id, &"hand_right")
	var right_reverse: Dictionary = await _equip_and_measure(player, reverse_wip.wip_id, &"hand_right")

	var lines: PackedStringArray = []
	lines.append("right_normal_forward=%s" % str(right_normal.get("forward", Vector3.ZERO)))
	lines.append("right_reverse_forward=%s" % str(right_reverse.get("forward", Vector3.ZERO)))

	for axis_name: String in AXIS_CANDIDATES.keys():
		var axis_vector: Vector3 = AXIS_CANDIDATES[axis_name]
		var left_normal: Dictionary = await _equip_and_measure(player, normal_wip.wip_id, &"hand_left")
		var left_normal_item: Node3D = left_normal.get("node", null) as Node3D
		if left_normal_item != null:
			left_normal_item.transform.basis = _build_candidate_basis(false, axis_vector)
			await process_frame
		left_normal = _capture_measurement(left_normal_item, player)

		var left_reverse: Dictionary = await _equip_and_measure(player, reverse_wip.wip_id, &"hand_left")
		var left_reverse_item: Node3D = left_reverse.get("node", null) as Node3D
		if left_reverse_item != null:
			left_reverse_item.transform.basis = _build_candidate_basis(true, axis_vector)
			await process_frame
		left_reverse = _capture_measurement(left_reverse_item, player)

		lines.append("%s left_normal_vs_right_normal=%s left_reverse_vs_right_reverse=%s left_normal_up=%s left_reverse_up=%s" % [
			axis_name,
			str(snappedf((left_normal.get("forward", Vector3.ZERO) as Vector3).dot(right_normal.get("forward", Vector3.ZERO) as Vector3), 0.0001)),
			str(snappedf((left_reverse.get("forward", Vector3.ZERO) as Vector3).dot(right_reverse.get("forward", Vector3.ZERO) as Vector3), 0.0001)),
			str(snappedf(float(left_normal.get("up_score", -2.0)), 0.0001)),
			str(snappedf(float(left_reverse.get("up_score", -2.0)), 0.0001))
		])

	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()

func _equip_and_measure(player: PlayerController3D, saved_wip_id: StringName, slot_id: StringName) -> Dictionary:
	player.clear_equipment_slot(&"hand_right")
	player.clear_equipment_slot(&"hand_left")
	await process_frame
	await process_frame
	player.equip_saved_wip_to_hand(saved_wip_id, slot_id)
	await process_frame
	await process_frame
	var held_item: Node3D = player.held_item_nodes.get(slot_id) as Node3D
	return _capture_measurement(held_item, player)

func _capture_measurement(held_item: Node3D, player: PlayerController3D) -> Dictionary:
	if held_item == null:
		return {
			"exists": false,
			"node": null,
			"forward": Vector3.ZERO,
			"up_score": -2.0
		}
	var player_forward: Vector3 = -player.visual_root.global_basis.z.normalized()
	return {
		"exists": true,
		"node": held_item,
		"forward": held_item.global_basis.x.normalized(),
		"up_score": held_item.global_basis.y.normalized().dot(Vector3.UP),
		"forward_score": held_item.global_basis.x.normalized().dot(player_forward)
	}

func _build_candidate_basis(reverse_grip: bool, correction_axis: Vector3) -> Basis:
	var final_basis := Basis.IDENTITY
	final_basis *= Basis(Vector3.RIGHT, PI)
	if reverse_grip:
		final_basis *= Basis(Vector3.UP, PI)
	final_basis *= Basis(correction_axis, PI)
	return final_basis.orthonormalized()

func _build_valid_test_wip(wip_id: StringName, grip_style_mode: StringName) -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = wip_id
	wip.forge_project_name = String(wip_id)
	wip.creator_id = &"verify"
	wip.created_timestamp = Time.get_unix_time_from_system()
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.grip_style_mode = grip_style_mode
	var layer_a: LayerAtom = LayerAtom.new()
	layer_a.layer_index = 20
	layer_a.cells = _build_handle_cells(20)
	var layer_b: LayerAtom = LayerAtom.new()
	layer_b.layer_index = 21
	layer_b.cells = _build_handle_cells(21)
	wip.layers = [layer_a, layer_b]
	return wip

func _build_handle_cells(layer_index: int) -> Array[CellAtom]:
	var cells: Array[CellAtom] = []
	for x in range(20, 32):
		for y in range(10, 13):
			var cell: CellAtom = CellAtom.new()
			cell.grid_position = Vector3i(x, y, layer_index)
			cell.layer_index = layer_index
			cell.material_variant_id = &"mat_wood_gray"
			cells.append(cell)
	return cells
