extends SceneTree

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationDraftScript = preload("res://core/models/combat_animation_draft.gd")
const CombatAnimationStationStateScript = preload("res://core/models/combat_animation_station_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")
const LayerAtomScript = preload("res://core/atoms/layer_atom.gd")
const CellAtomScript = preload("res://core/atoms/cell_atom.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/DEBUG-LOGS/combat_animation_station_noncombat_stow_marker_results.txt"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/verify_combat_animation_station_noncombat_stow_marker_library.tres"
const WOOD_MATERIAL_ID := &"mat_wood_gray"
const PIVOT_EPSILON := 0.001
const LENGTH_EPSILON := 0.001
const WATCHDOG_SECONDS := 45.0

var result_lines: PackedStringArray = []
var active_step: String = "not_started"
var started_msec: int = 0

class FakePlayer:
	extends Node

	var ui_mode_enabled: bool = false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

func _init() -> void:
	started_msec = Time.get_ticks_msec()
	_checkpoint("init")
	call_deferred("_run_verification")
	call_deferred("_run_watchdog")

func _run_verification() -> void:
	_checkpoint("build_library_state")
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	library_state.save_file_path = TEMP_SAVE_FILE_PATH
	library_state.saved_wips.clear()
	library_state.selected_wip_id = StringName()

	_checkpoint("build_preview_test_wip")
	var source_wip: CraftedItemWIP = _build_preview_test_wip()
	_checkpoint("save_preview_test_wip")
	var saved_wip: CraftedItemWIP = library_state.save_wip(source_wip)
	var saved_wip_id: StringName = saved_wip.wip_id if saved_wip != null else StringName()
	_append_result("saved_wip_id=%s" % String(saved_wip_id))

	_checkpoint("create_fake_player")
	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library_state
	get_root().add_child(fake_player)

	_checkpoint("instantiate_ui")
	var ui = CombatAnimationStationUIScene.instantiate()
	ui.set_meta("verification_skip_persistence", true)
	get_root().add_child(ui)
	_checkpoint("await_ui_ready_before")
	await process_frame
	_checkpoint("await_ui_ready_after")
	_checkpoint("open_ui_before")
	ui.open_for(fake_player, "Noncombat Stow Marker Verifier")
	_checkpoint("open_ui_after")
	await process_frame
	_checkpoint("open_saved_wip_right_before")
	var opened_right: bool = ui.open_saved_wip_with_hand_setup(saved_wip_id, &"hand_right", false, false)
	_append_result("opened_right=%s" % str(opened_right))
	_checkpoint("open_saved_wip_right_after")
	await process_frame
	_checkpoint("select_idle_mode_before")
	ui.select_authoring_mode(CombatAnimationStationStateScript.AUTHORING_MODE_IDLE)
	_checkpoint("select_idle_mode_after")
	await process_frame
	_checkpoint("select_noncombat_draft_before")
	ui.select_draft(CombatAnimationStationStateScript.IDLE_CONTEXT_NONCOMBAT, true)
	_checkpoint("select_noncombat_draft_after")
	await process_frame
	_checkpoint("refresh_preview_scene_before")
	ui.call("_refresh_preview_scene")
	_checkpoint("refresh_preview_scene_after")
	await process_frame

	_checkpoint("read_initial_debug_state")
	var debug_state: Dictionary = ui.get_preview_debug_state()
	var marker_ids: Array = debug_state.get("stow_anchor_marker_ids", []) as Array
	var marker_positions: Dictionary = debug_state.get("stow_anchor_marker_positions_local", {}) as Dictionary
	var marker_positions_origin_id: StringName = StringName(debug_state.get(
		"stow_anchor_marker_positions_origin_id",
		StringName()
	))
	var marker_position_origin_ids: Dictionary = debug_state.get("stow_anchor_marker_position_origin_ids", {}) as Dictionary
	var selected_marker_id: StringName = debug_state.get("selected_stow_anchor_marker_id", StringName()) as StringName
	var selected_slot_id: StringName = debug_state.get("selected_stow_anchor_slot_id", StringName()) as StringName
	var selected_mode: StringName = debug_state.get("selected_stow_anchor_mode", StringName()) as StringName
	var selected_orientation_side: StringName = debug_state.get("selected_stow_anchor_orientation_side", StringName()) as StringName
	var preview_pose_mode: StringName = debug_state.get("preview_pose_mode", StringName()) as StringName
	var upper_body_authoring_active: bool = bool(debug_state.get("upper_body_authoring_active", true))
	var contact_coupling_metrics: Dictionary = debug_state.get("contact_coupling_metrics", {}) as Dictionary
	var stow_option_labels: PackedStringArray = []
	for item_index: int in range(ui.stow_anchor_option_button.get_item_count()):
		stow_option_labels.append(ui.stow_anchor_option_button.get_item_text(item_index))
	var expected_ids: Array[StringName] = [
		&"stow_upper_back_l",
		&"stow_upper_back_r",
		&"stow_lower_back_center",
		&"stow_hip_l",
		&"stow_hip_r",
	]
	var expected_option_labels: PackedStringArray = ["Upper Back", "Lower Back", "Hip"]
	var ids_ok: bool = marker_ids.size() == expected_ids.size()
	for expected_id: StringName in expected_ids:
		ids_ok = ids_ok and marker_ids.has(expected_id)
	var positions_ok: bool = marker_positions.size() == expected_ids.size()
	for expected_id: StringName in expected_ids:
		positions_ok = positions_ok and marker_positions.has(expected_id)
	var positions_origin_ok: bool = (
		marker_positions_origin_id == CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		and marker_position_origin_ids.size() == expected_ids.size()
	)
	for expected_id: StringName in expected_ids:
		positions_origin_ok = (
			positions_origin_ok
			and StringName(marker_position_origin_ids.get(expected_id, StringName())) == CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		)
	var labels_ok: bool = stow_option_labels.size() == expected_option_labels.size()
	for item_index: int in range(expected_option_labels.size()):
		labels_ok = labels_ok and stow_option_labels[item_index] == expected_option_labels[item_index]
	var decoupled_pose_ok: bool = (
		preview_pose_mode == &"noncombat_stow"
		and not upper_body_authoring_active
		and String(contact_coupling_metrics.get("stopped_reason", "")) == "noncombat_stow_decoupled"
		and not bool(contact_coupling_metrics.get("hands_interact_with_weapon", true))
	)
	var active_draft: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	var active_motion_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var initial_contact_ratio: float = CombatAnimationDraftScript.normalize_stow_contact_ratio(active_draft.stow_contact_ratio) if active_draft != null else -1.0
	var initial_pivot_local: Vector3 = active_motion_node.pommel_position_local.lerp(active_motion_node.tip_position_local, initial_contact_ratio) if active_motion_node != null else Vector3.INF
	var initial_segment_length: float = active_motion_node.pommel_position_local.distance_to(active_motion_node.tip_position_local) if active_motion_node != null else 0.0
	var initial_contact_ok: bool = (
		is_equal_approx(initial_contact_ratio, CombatAnimationDraftScript.DEFAULT_STOW_CONTACT_RATIO)
		and initial_pivot_local.distance_to(Vector3.ZERO) <= PIVOT_EPSILON
		and initial_segment_length > LENGTH_EPSILON
		and is_equal_approx(float(ui.stow_contact_ratio_spin_box.value), CombatAnimationDraftScript.DEFAULT_STOW_CONTACT_RATIO)
	)
	ui.set_active_draft_stow_contact_ratio(0.25)
	await process_frame
	active_draft = ui.call("_get_active_draft") as CombatAnimationDraft
	active_motion_node = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var quarter_contact_ratio: float = CombatAnimationDraftScript.normalize_stow_contact_ratio(active_draft.stow_contact_ratio) if active_draft != null else -1.0
	var quarter_pivot_local: Vector3 = active_motion_node.pommel_position_local.lerp(active_motion_node.tip_position_local, quarter_contact_ratio) if active_motion_node != null else Vector3.INF
	var quarter_segment_length: float = active_motion_node.pommel_position_local.distance_to(active_motion_node.tip_position_local) if active_motion_node != null else 0.0
	var requested_tip: Vector3 = quarter_pivot_local + Vector3(0.0, quarter_segment_length, 0.0)
	ui.set_selected_motion_node_tip_position(requested_tip, false, false, false, false, false)
	await process_frame
	active_motion_node = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var tip_edit_pivot_local: Vector3 = active_motion_node.pommel_position_local.lerp(active_motion_node.tip_position_local, quarter_contact_ratio) if active_motion_node != null else Vector3.INF
	var tip_edit_axis: Vector3 = active_motion_node.tip_position_local - active_motion_node.pommel_position_local if active_motion_node != null else Vector3.ZERO
	var contact_ratio_ok: bool = (
		is_equal_approx(quarter_contact_ratio, 0.25)
		and quarter_pivot_local.distance_to(Vector3.ZERO) <= PIVOT_EPSILON
		and is_equal_approx(quarter_segment_length, initial_segment_length)
		and tip_edit_pivot_local.distance_to(Vector3.ZERO) <= PIVOT_EPSILON
		and tip_edit_axis.normalized().dot(Vector3.UP) > 0.99
	)
	ui.set_active_draft_stow_anchor_mode(CombatAnimationDraftScript.STOW_ANCHOR_SIDE_HIP)
	await process_frame
	var hip_debug_state: Dictionary = ui.get_preview_debug_state()
	var hip_selected_id: StringName = hip_debug_state.get("selected_stow_anchor_marker_id", StringName()) as StringName
	var hip_orientation_side: StringName = hip_debug_state.get("selected_stow_anchor_orientation_side", StringName()) as StringName
	ui.set_active_draft_stow_anchor_mode(CombatAnimationDraftScript.STOW_ANCHOR_LOWER_BACK)
	await process_frame
	var lower_debug_state: Dictionary = ui.get_preview_debug_state()
	var lower_selected_id: StringName = lower_debug_state.get("selected_stow_anchor_marker_id", StringName()) as StringName
	var lower_orientation_side: StringName = lower_debug_state.get("selected_stow_anchor_orientation_side", StringName()) as StringName
	_checkpoint("open_saved_wip_left_before")
	var opened_left: bool = ui.open_saved_wip_with_hand_setup(saved_wip_id, &"hand_left", false, false)
	_append_result("opened_left=%s" % str(opened_left))
	_checkpoint("open_saved_wip_left_after")
	await process_frame
	ui.select_authoring_mode(CombatAnimationStationStateScript.AUTHORING_MODE_IDLE)
	await process_frame
	ui.select_draft(CombatAnimationStationStateScript.IDLE_CONTEXT_NONCOMBAT, true)
	await process_frame
	ui.set_active_draft_stow_anchor_mode(CombatAnimationDraftScript.STOW_ANCHOR_SHOULDER_HANGING)
	await process_frame
	var left_debug_state: Dictionary = ui.get_preview_debug_state()
	var left_upper_selected_id: StringName = left_debug_state.get("selected_stow_anchor_marker_id", StringName()) as StringName
	var left_upper_orientation_side: StringName = left_debug_state.get("selected_stow_anchor_orientation_side", StringName()) as StringName
	var all_checks_passed: bool = (
		bool(debug_state.get("has_preview_actor", false))
		and int(debug_state.get("stow_anchor_marker_count", 0)) == expected_ids.size()
		and ids_ok
		and positions_ok
		and positions_origin_ok
		and labels_ok
		and selected_marker_id == &"stow_upper_back_l"
		and selected_slot_id == &"hand_right"
		and selected_orientation_side == &"left"
		and hip_selected_id == &"stow_hip_l"
		and hip_orientation_side == &"left"
		and lower_selected_id == &"stow_lower_back_center"
		and lower_orientation_side == &"right"
		and left_upper_selected_id == &"stow_upper_back_r"
		and left_upper_orientation_side == &"right"
		and decoupled_pose_ok
		and initial_contact_ok
		and contact_ratio_ok
	)

	var lines: PackedStringArray = result_lines.duplicate()
	lines.append("final_step=%s" % active_step)
	lines.append("has_preview_actor=%s" % str(bool(debug_state.get("has_preview_actor", false))))
	lines.append("stow_anchor_marker_count=%d" % int(debug_state.get("stow_anchor_marker_count", 0)))
	lines.append("stow_anchor_marker_ids=%s" % str(marker_ids))
	lines.append("stow_anchor_marker_positions_local=%s" % str(marker_positions))
	lines.append("stow_anchor_marker_positions_origin_id=%s" % String(marker_positions_origin_id))
	lines.append("stow_anchor_marker_position_origin_ids=%s" % str(marker_position_origin_ids))
	lines.append("selected_stow_anchor_marker_id=%s" % String(selected_marker_id))
	lines.append("selected_stow_anchor_slot_id=%s" % String(selected_slot_id))
	lines.append("selected_stow_anchor_mode=%s" % String(selected_mode))
	lines.append("selected_stow_anchor_orientation_side=%s" % String(selected_orientation_side))
	lines.append("preview_pose_mode=%s" % String(preview_pose_mode))
	lines.append("upper_body_authoring_active=%s" % str(upper_body_authoring_active))
	lines.append("contact_coupling_metrics=%s" % str(contact_coupling_metrics))
	lines.append("decoupled_pose_ok=%s" % str(decoupled_pose_ok))
	lines.append("stow_option_labels=%s" % str(stow_option_labels))
	lines.append("labels_ok=%s" % str(labels_ok))
	lines.append("hip_selected_stow_anchor_marker_id=%s" % String(hip_selected_id))
	lines.append("hip_selected_stow_anchor_orientation_side=%s" % String(hip_orientation_side))
	lines.append("lower_selected_stow_anchor_marker_id=%s" % String(lower_selected_id))
	lines.append("lower_selected_stow_anchor_orientation_side=%s" % String(lower_orientation_side))
	lines.append("left_upper_selected_stow_anchor_marker_id=%s" % String(left_upper_selected_id))
	lines.append("left_upper_selected_stow_anchor_orientation_side=%s" % String(left_upper_orientation_side))
	lines.append("initial_contact_ratio=%s" % str(initial_contact_ratio))
	lines.append("initial_stow_pivot_local=%s" % str(initial_pivot_local))
	lines.append("initial_stow_segment_length=%s" % str(initial_segment_length))
	lines.append("initial_contact_ok=%s" % str(initial_contact_ok))
	lines.append("quarter_contact_ratio=%s" % str(quarter_contact_ratio))
	lines.append("quarter_stow_pivot_local=%s" % str(quarter_pivot_local))
	lines.append("quarter_stow_segment_length=%s" % str(quarter_segment_length))
	lines.append("tip_edit_stow_pivot_local=%s" % str(tip_edit_pivot_local))
	lines.append("tip_edit_axis=%s" % str(tip_edit_axis))
	lines.append("contact_ratio_ok=%s" % str(contact_ratio_ok))
	lines.append("ids_ok=%s" % str(ids_ok))
	lines.append("positions_ok=%s" % str(positions_ok))
	lines.append("positions_origin_ok=%s" % str(positions_origin_ok))
	lines.append("all_checks_passed=%s" % str(all_checks_passed))
	_write_result_lines(lines)
	ui.queue_free()
	fake_player.queue_free()
	await process_frame
	quit(0 if all_checks_passed else 1)

func _run_watchdog() -> void:
	await create_timer(WATCHDOG_SECONDS).timeout
	_append_result("watchdog_timeout=true")
	_append_result("watchdog_timeout_step=%s" % active_step)
	_append_result("watchdog_timeout_seconds=%s" % str(WATCHDOG_SECONDS))
	quit(2)

func _checkpoint(step: String) -> void:
	active_step = step
	_append_result("checkpoint=%s elapsed_msec=%d" % [
		active_step,
		Time.get_ticks_msec() - started_msec,
	])

func _append_result(line: String) -> void:
	result_lines.append(line)
	_write_result_lines(result_lines)

func _write_result_lines(lines: PackedStringArray) -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_FILE_PATH.get_base_dir())
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

func _build_preview_test_wip() -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIPScript.new()
	wip.wip_id = &"noncombat_stow_marker_test_wip"
	wip.forge_project_name = "Noncombat Stow Marker Verifier"
	CraftedItemWIPScript.apply_builder_path_defaults(
		wip,
		CraftedItemWIPScript.BUILDER_PATH_MELEE,
		CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	)
	var layer_map: Dictionary = {}
	for slice_index: int in range(26):
		for y in range(4, 6):
			for z in range(4, 7):
				_add_cell(layer_map, Vector3i(slice_index, y, z), WOOD_MATERIAL_ID)
	var ordered_layers: Array = layer_map.keys()
	ordered_layers.sort()
	for layer_index_value: Variant in ordered_layers:
		wip.layers.append(layer_map[layer_index_value])
	wip.latest_baked_profile_snapshot = _build_preview_test_baked_profile()
	return wip

func _build_preview_test_baked_profile() -> BakedProfile:
	var profile := BakedProfile.new()
	profile.profile_id = &"noncombat_stow_marker_test_profile"
	profile.primary_grip_valid = true
	profile.primary_grip_contact_position = Vector3(13.0, 4.5, 5.0)
	profile.primary_grip_axis_ratio_from_span_start = 0.5
	profile.primary_grip_contact_percent = 50.0
	profile.primary_grip_span_start = Vector3(0.0, 4.5, 5.0)
	profile.primary_grip_span_end = Vector3(26.0, 4.5, 5.0)
	profile.primary_grip_span_length_voxels = 26
	profile.primary_grip_slide_axis = Vector3.RIGHT
	profile.primary_grip_center_balance_valid = true
	profile.weapon_pommel_point = Vector3(0.0, 4.5, 5.0)
	profile.weapon_tip_point = Vector3(26.0, 4.5, 5.0)
	profile.weapon_total_length_meters = 0.325
	profile.weapon_pommel_distance_meters = 0.1625
	profile.weapon_tip_distance_meters = 0.1625
	return profile

func _add_cell(layer_map: Dictionary, grid_position: Vector3i, material_variant_id: StringName) -> void:
	if not layer_map.has(grid_position.z):
		var layer: LayerAtom = LayerAtomScript.new()
		layer.layer_index = grid_position.z
		layer.cells = []
		layer_map[grid_position.z] = layer
	var cell: CellAtom = CellAtomScript.new()
	cell.grid_position = grid_position
	cell.layer_index = grid_position.z
	cell.material_variant_id = material_variant_id
	var target_layer: LayerAtom = layer_map[grid_position.z]
	target_layer.cells.append(cell)
