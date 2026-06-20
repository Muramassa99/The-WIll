extends "res://tools/diagnose_runtime_skill_slot_2_posture_weapon_legality.gd"

const CombatAnimationDraftScript = preload("res://core/models/combat_animation_draft.gd")
const CombatAnimationRuntimeChainCompilerScript = preload("res://core/resolvers/combat_animation_runtime_chain_compiler.gd")
const CombatRuntimeClipBakerScript = preload("res://core/resolvers/combat_runtime_clip_baker.gd")
const CombatAnimationStationPreviewPresenterScript = preload("res://runtime/combat/combat_animation_station_preview_presenter.gd")

const SEQUENCE_RESULT_FILE_PATH := "C:/WORKSPACE/DEBUG-LOGS/runtime_skill_sequence_2_then_1_posture_weapon_legality_30s_2026-05-04.log"
const SEQUENCE_SAMPLE_FILE_PATH := "C:/WORKSPACE/DEBUG-LOGS/runtime_skill_sequence_2_then_1_posture_weapon_legality_30s_samples_2026-05-04.csv"
const SEQUENCE_SNAPSHOT_DIR := "C:/WORKSPACE/DEBUG-LOGS/runtime_skill_sequence_2_then_1_visual_snapshots_2026-05-04"
const SEQUENCE_TEMP_LIBRARY_SAVE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_runtime_skill_sequence_2_then_1_posture_weapon_legality_library.tres"
const SEQUENCE_TEMP_SKILL_SLOT_SAVE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_runtime_skill_sequence_2_then_1_posture_weapon_legality_slots.tres"
const SEQUENCE_TEMP_EQUIPMENT_SAVE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_runtime_skill_sequence_2_then_1_posture_weapon_legality_equipment.tres"
const FIRST_SEQUENCE_SLOT_ID: StringName = &"skill_slot_2"
const SECOND_SEQUENCE_SLOT_ID: StringName = &"skill_slot_1"
const FIRST_SEQUENCE_TRIGGER_SECONDS := 5.0
const SECOND_SEQUENCE_TRIGGER_SECONDS := 10.0
const SEQUENCE_OBSERVE_SECONDS := 30.0
const SEQUENCE_SNAPSHOT_SAMPLE_INDICES := [0, 300, 305, 600, 605, 900, 1200, 1500, 1800]

func _init() -> void:
	call_deferred("_run_diagnostic")

func _run_diagnostic() -> void:
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/DEBUG-LOGS")
	DirAccess.make_dir_recursive_absolute(SEQUENCE_SNAPSHOT_DIR)
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/test_artifacts")
	_reset_outputs()
	result_lines.append("diagnostic=runtime_skill_sequence_2_then_1_posture_weapon_legality")
	result_lines.append("target_project_name=%s" % TARGET_PROJECT_NAME)
	result_lines.append("first_slot_id=%s" % String(FIRST_SEQUENCE_SLOT_ID))
	result_lines.append("second_slot_id=%s" % String(SECOND_SEQUENCE_SLOT_ID))
	result_lines.append("dominant_equipment_slot_id=%s" % String(DOMINANT_EQUIPMENT_SLOT_ID))
	result_lines.append("observe_seconds=%.3f" % SEQUENCE_OBSERVE_SECONDS)
	result_lines.append("first_trigger_seconds=%.3f" % FIRST_SEQUENCE_TRIGGER_SECONDS)
	result_lines.append("second_trigger_seconds=%.3f" % SECOND_SEQUENCE_TRIGGER_SECONDS)
	result_lines.append("seconds_between_skill_inputs=%.3f" % (SECOND_SEQUENCE_TRIGGER_SECONDS - FIRST_SEQUENCE_TRIGGER_SECONDS))
	result_lines.append("activation_input_sequence=KEY_2_then_KEY_1")
	result_lines.append("visual_snapshot_dir=%s" % SEQUENCE_SNAPSHOT_DIR)
	var use_saved_runtime_clip_cache: bool = _use_saved_runtime_clip_cache()
	var source_library_path: String = _resolve_source_library_path()
	result_lines.append("use_saved_runtime_clip_cache=%s" % str(use_saved_runtime_clip_cache))
	result_lines.append("source_library_path=%s" % source_library_path)

	var source_library = (
		PlayerForgeWipLibraryStateScript.load_or_create(source_library_path)
		if not source_library_path.is_empty()
		else PlayerForgeWipLibraryStateScript.load_or_create()
	)
	var source_wip = _find_saved_wip_by_project_name(source_library, TARGET_PROJECT_NAME)
	result_lines.append("source_library_loaded=%s" % str(source_library != null))
	result_lines.append("source_wip_found=%s" % str(source_wip != null))
	if source_wip == null:
		_write_outputs()
		quit(1)
		return

	var diagnostic_wip = source_wip.duplicate(true)
	diagnostic_wip.wip_id = StringName("%s_runtime_sequence_2_then_1_diagnostic" % String(source_wip.wip_id))
	diagnostic_wip.forge_project_name = "%s Runtime Sequence 2 Then 1 Diagnostic" % source_wip.forge_project_name
	diagnostic_wip.ensure_combat_animation_station_state()
	var cache_refresh_result: Dictionary = (
		_build_skipped_cache_refresh_result()
		if use_saved_runtime_clip_cache
		else await _refresh_diagnostic_wip_solved_runtime_clips(diagnostic_wip)
	)
	result_lines.append("diagnostic_runtime_clip_cache_refresh=%s" % str(cache_refresh_result))
	var temp_library = PlayerForgeWipLibraryStateScript.new()
	temp_library.save_file_path = SEQUENCE_TEMP_LIBRARY_SAVE_PATH
	temp_library.saved_wips.clear()
	temp_library.saved_wips.append(diagnostic_wip)
	temp_library.selected_wip_id = diagnostic_wip.wip_id
	temp_library.persist()

	var equipment_state = PlayerEquipmentStateScript.new()
	equipment_state.save_file_path = SEQUENCE_TEMP_EQUIPMENT_SAVE_PATH
	equipment_state.equipped_slots.clear()
	var equipped_entry = equipment_state.equip_forge_test_wip(DOMINANT_EQUIPMENT_SLOT_ID, diagnostic_wip)

	var skill_slot_state = PlayerSkillSlotStateScript.new()
	skill_slot_state.save_file_path = SEQUENCE_TEMP_SKILL_SLOT_SAVE_PATH
	skill_slot_state.slot_assignments.clear()

	var root_scene: Node = MainScene.instantiate()
	var player: PlayerController3D = root_scene.get_node_or_null("PlayerCharacter") as PlayerController3D
	if player == null:
		player = _find_player_controller(root_scene)
	result_lines.append("main_scene_loaded=%s" % str(root_scene != null))
	result_lines.append("main_scene_player_found=%s" % str(player != null))
	if player == null:
		_write_outputs()
		quit(1)
		return

	player.equipment_state = equipment_state
	player.forge_wip_library_state = temp_library
	player.player_skill_slot_state = skill_slot_state
	player.weapons_drawn = true
	player.velocity = Vector3.ZERO
	root.add_child(root_scene)
	await _wait_frames(8)
	if player.humanoid_rig != null:
		player.humanoid_rig.show_two_hand_grip_debug_markers = true
	result_lines.append("runtime_grip_debug_markers_forced_visible=%s" % str(player.humanoid_rig != null))
	await _wait_until_player_grounded(player, 90)
	player.call("_sync_equipped_test_meshes")
	player.call("_sync_equipped_skill_slots")
	await _wait_frames(6)
	await _wait_physics_frames(2)
	await _capture_sequence_debug_snapshot("pre_activation")

	result_lines.append("source_wip_id=%s" % String(source_wip.wip_id))
	result_lines.append("diagnostic_wip_id=%s" % String(diagnostic_wip.wip_id))
	result_lines.append("diagnostic_save_path=%s" % SEQUENCE_TEMP_LIBRARY_SAVE_PATH)
	result_lines.append("equipment_entry_exists=%s" % str(equipped_entry != null))
	result_lines.append("main_scene_player_path=%s" % str(player.get_path()))
	result_lines.append("held_item_count=%d" % player.held_item_nodes.size())
	result_lines.append("held_item_slots=%s" % ", ".join(_string_name_keys(player.held_item_nodes)))
	result_lines.append("player_grounded_before_activation=%s" % str(player.is_on_floor()))
	result_lines.append("player_global_position_before_activation=%s" % str(player.global_position))
	result_lines.append_array(_build_seating_debug_lines(player, "pre_activation"))

	var preview_result_2: Dictionary = player.preview_runtime_skill_slot_activation(FIRST_SEQUENCE_SLOT_ID)
	result_lines.append_array(_build_preview_lines(preview_result_2, "preview_skill_2"))
	var preview_result_1: Dictionary = player.preview_runtime_skill_slot_activation(SECOND_SEQUENCE_SLOT_ID)
	result_lines.append_array(_build_preview_lines(preview_result_1, "preview_skill_1"))

	var elapsed: float = 0.0
	var sample_index: int = 0
	var first_activation_sent := false
	var second_activation_sent := false
	while elapsed <= SEQUENCE_OBSERVE_SECONDS:
		if not first_activation_sent and elapsed >= FIRST_SEQUENCE_TRIGGER_SECONDS:
			var input_activation_2_sent: bool = await _press_key(KEY_2)
			first_activation_sent = true
			result_lines.append("input_key_2_sent=%s" % str(input_activation_2_sent))
			result_lines.append("input_key_2_elapsed_seconds=%.4f" % elapsed)
			result_lines.append("input_key_2_sample_index=%d" % sample_index)
			_append_activation_lines(player, "activation_skill_2")
			result_lines.append_array(_build_seating_debug_lines(player, "post_skill_2_activation"))
		if not second_activation_sent and elapsed >= SECOND_SEQUENCE_TRIGGER_SECONDS:
			var input_activation_1_sent: bool = await _press_key(KEY_1)
			second_activation_sent = true
			result_lines.append("input_key_1_sent=%s" % str(input_activation_1_sent))
			result_lines.append("input_key_1_elapsed_seconds=%.4f" % elapsed)
			result_lines.append("input_key_1_sample_index=%d" % sample_index)
			_append_activation_lines(player, "activation_skill_1")
			result_lines.append_array(_build_seating_debug_lines(player, "post_skill_1_activation"))
		_sample_runtime(player, sample_index, elapsed)
		if SEQUENCE_SNAPSHOT_SAMPLE_INDICES.has(sample_index):
			await _capture_sequence_debug_snapshot("sample_%04d_%05.2fs" % [sample_index, elapsed])
		if sample_index == 0:
			result_lines.append_array(_build_seating_debug_lines(player, "test_start_sample_0"))
		await physics_frame
		await process_frame
		elapsed += 1.0 / 60.0
		sample_index += 1

	var final_runtime_debug: Dictionary = player.get_runtime_skill_playback_debug_state()
	var final_idle_debug: Dictionary = player.get_runtime_idle_pose_debug_state()
	var final_grip_debug: Dictionary = _get_grip_debug(player)
	var final_body_self: Dictionary = _get_body_self_debug(player)
	var final_body_clearance: Dictionary = _get_body_clearance_debug(player)
	result_lines.append("sample_count=%d" % sample_index)
	result_lines.append("runtime_active_final=%s" % str(bool(final_runtime_debug.get("active", false))))
	result_lines.append("runtime_idle_active_final=%s" % str(bool(final_idle_debug.get("active", false))))
	result_lines.append("runtime_finished_pending_final=%s" % str(bool(final_runtime_debug.get("playback_finished_pending", false))))
	result_lines.append("hidden_bridge_state_final=%s" % str(final_runtime_debug.get("hidden_bridge_state", {})))
	result_lines.append("player_grounded_final=%s" % str(player.is_on_floor()))
	result_lines.append("player_global_position_final=%s" % str(player.global_position))
	result_lines.append("upper_body_authoring_active_final=%s" % str(bool((_get_upper_body_state(player).get("active", false)))))
	result_lines.append("final_body_clearance_proxy_source=%s" % str(final_body_clearance.get("body_clearance_proxy_source", StringName())))
	result_lines.append("final_body_clearance_attachment_count=%d" % int(final_body_clearance.get("body_clearance_attachment_count", 0)))
	result_lines.append("final_body_self_legal=%s" % str(bool(final_body_self.get("legal", true))))
	result_lines.append("final_body_self_illegal_pair_count=%d" % int(final_body_self.get("illegal_pair_count", 0)))
	result_lines.append("final_body_self_first_illegal_pair=%s" % str(final_body_self.get("first_illegal_pair", {})))
	result_lines.append("final_right_hand_ik_target_distance_meters=%.6f" % float(final_grip_debug.get("right_hand_ik_target_distance_meters", -1.0)))
	result_lines.append("final_left_hand_ik_target_distance_meters=%.6f" % float(final_grip_debug.get("left_hand_ik_target_distance_meters", -1.0)))
	result_lines.append_array(_build_stat_lines())
	result_lines.append_array(_build_legality_summary())
	_write_outputs()
	quit(0 if _all_core_legality_checks_passed() else 1)

func _use_saved_runtime_clip_cache() -> bool:
	for argument: String in OS.get_cmdline_args():
		if argument == "--use-saved-cache":
			return true
	return false

func _resolve_source_library_path() -> String:
	for argument: String in OS.get_cmdline_args():
		if argument.begins_with("--source-library-path="):
			return argument.trim_prefix("--source-library-path=").strip_edges()
	return ""

func _build_skipped_cache_refresh_result() -> Dictionary:
	return {
		"attempted": false,
		"skipped": true,
		"reason": "using_saved_runtime_clip_cache",
		"cached_count": 0,
		"solved_count": 0,
		"failed_count": 0,
		"results": [],
	}

func _refresh_diagnostic_wip_solved_runtime_clips(diagnostic_wip: CraftedItemWIP) -> Dictionary:
	var result := {
		"attempted": false,
		"cached_count": 0,
		"solved_count": 0,
		"failed_count": 0,
		"results": [],
	}
	if diagnostic_wip == null:
		return result
	var station_state: Resource = diagnostic_wip.combat_animation_station_state
	if station_state == null:
		return result
	result["attempted"] = true
	var preview_container := SubViewportContainer.new()
	preview_container.name = "DiagnosticSolvedReplayPreviewContainer"
	preview_container.size = Vector2(1280, 720)
	var preview_subviewport := SubViewport.new()
	preview_subviewport.name = "DiagnosticSolvedReplaySubViewport"
	preview_subviewport.size = Vector2i(1280, 720)
	preview_container.add_child(preview_subviewport)
	root.add_child(preview_container)
	await process_frame
	var preview_presenter = CombatAnimationStationPreviewPresenterScript.new()
	var runtime_clip_baker = CombatRuntimeClipBakerScript.new()
	var runtime_chain_compiler = CombatAnimationRuntimeChainCompilerScript.new()
	var current_weapon_length: float = _resolve_diagnostic_weapon_length_meters(diagnostic_wip, station_state)
	var drafts: Array = []
	for skill_draft: Resource in station_state.get("skill_drafts") as Array:
		drafts.append(skill_draft)
	for idle_draft: Resource in station_state.get("idle_drafts") as Array:
		if idle_draft != null and StringName(idle_draft.get("context_id")) == CombatAnimationDraftScript.IDLE_CONTEXT_COMBAT:
			drafts.append(idle_draft)
	for draft: Resource in drafts:
		var draft_result: Dictionary = _refresh_diagnostic_draft_solved_runtime_clip(
			diagnostic_wip,
			draft,
			preview_container,
			preview_subviewport,
			preview_presenter,
			runtime_clip_baker,
			runtime_chain_compiler,
			current_weapon_length
		)
		(result["results"] as Array).append(draft_result)
		if bool(draft_result.get("cached", false)):
			result["cached_count"] = int(result.get("cached_count", 0)) + 1
			if bool(draft_result.get("solved_replay_track", false)):
				result["solved_count"] = int(result.get("solved_count", 0)) + 1
		else:
			result["failed_count"] = int(result.get("failed_count", 0)) + 1
	preview_container.queue_free()
	return result

func _refresh_diagnostic_draft_solved_runtime_clip(
	diagnostic_wip: CraftedItemWIP,
	draft: Resource,
	preview_container: SubViewportContainer,
	preview_subviewport: SubViewport,
	preview_presenter,
	runtime_clip_baker,
	runtime_chain_compiler,
	current_weapon_length: float
) -> Dictionary:
	var result := {
		"cached": false,
		"solved_replay_track": false,
		"reason": "",
		"draft_id": StringName(),
		"frame_count": 0,
	}
	if draft == null:
		result["reason"] = "no_draft"
		return result
	result["draft_id"] = StringName(draft.get("draft_id"))
	var motion_node_chain: Array = draft.get("motion_node_chain") as Array
	if motion_node_chain.is_empty():
		result["reason"] = "empty_motion_node_chain"
		return result
	var draft_kind: StringName = StringName(draft.get("draft_kind"))
	var equipment_context := {
		"support_hand_available": true,
		"two_hand_allowed": true,
		"dominant_slot_id": DOMINANT_EQUIPMENT_SLOT_ID,
		"support_slot_id": &"hand_left",
	}
	var compile_result: Dictionary = (
		runtime_chain_compiler.compile_idle_chain(motion_node_chain, current_weapon_length, {}, equipment_context)
		if draft_kind == CombatAnimationDraftScript.DRAFT_KIND_IDLE
		else runtime_chain_compiler.compile_skill_chain(motion_node_chain, current_weapon_length, {}, equipment_context)
	)
	var playable_chain: Array = compile_result.get("motion_node_chain", motion_node_chain) as Array
	if playable_chain.is_empty():
		result["reason"] = "compiled_chain_empty"
		return result
	var runtime_clip = runtime_clip_baker.bake_from_motion_node_chain(
		playable_chain,
		{
			"clip_kind": &"idle" if draft_kind == CombatAnimationDraftScript.DRAFT_KIND_IDLE else &"skill_playback",
			"source_draft_id": StringName(draft.get("draft_id")),
			"source_skill_slot_id": StringName(draft.get("legal_slot_id")) if draft_kind != CombatAnimationDraftScript.DRAFT_KIND_IDLE else StringName(),
			"source_idle_context_id": StringName(draft.get("context_id")) if draft_kind == CombatAnimationDraftScript.DRAFT_KIND_IDLE else StringName(),
			"source_weapon_wip_id": diagnostic_wip.wip_id,
			"source_weapon_length_meters": current_weapon_length,
			"playback_speed_scale": float(draft.get("preview_playback_speed_scale")),
			"loop_enabled": bool(draft.get("preview_loop_enabled")),
			"trajectory_volume_config": {},
			"compile_diagnostics": compile_result.get("diagnostics", []),
			"degraded_node_count": int(compile_result.get("degraded_node_count", 0)),
			"hand_swap_bridge_count": int(compile_result.get("hand_swap_bridge_count", 0)),
			"retargeted_count": int(compile_result.get("retargeted_count", 0)),
		}
	)
	if runtime_clip == null or not runtime_clip.has_method("get_frame_count") or int(runtime_clip.call("get_frame_count")) <= 0:
		result["reason"] = "runtime_clip_bake_failed"
		return result
	var selected_node_index: int = clampi(int(draft.get("selected_motion_node_index")), 0, maxi(playable_chain.size() - 1, 0))
	var pose_result: Dictionary = preview_presenter.bake_runtime_clip_upper_body_pose_track(
		preview_container,
		preview_subviewport,
		diagnostic_wip,
		draft,
		runtime_clip,
		selected_node_index
	)
	draft.set("baked_runtime_clip", runtime_clip)
	result["cached"] = true
	result["frame_count"] = int(runtime_clip.call("get_frame_count"))
	result["solved_replay_track"] = bool(pose_result.get("solved_replay_track", false))
	result["f_playback_primary_anchor_to_anatomical_grip_max_meters"] = float(pose_result.get("primary_anchor_to_anatomical_grip_max_meters", -1.0))
	result["f_playback_primary_anchor_to_anatomical_grip_avg_meters"] = float(pose_result.get("primary_anchor_to_anatomical_grip_avg_meters", -1.0))
	result["f_playback_primary_anchor_to_anatomical_grip_max_frame"] = int(pose_result.get("primary_anchor_to_anatomical_grip_max_frame", -1))
	result["reason"] = String(pose_result.get("reason", ""))
	return result

func _resolve_diagnostic_weapon_length_meters(diagnostic_wip: CraftedItemWIP, station_state: Resource) -> float:
	if diagnostic_wip != null and diagnostic_wip.latest_baked_profile_snapshot != null:
		var profile_length: float = float(diagnostic_wip.latest_baked_profile_snapshot.weapon_total_length_meters)
		if profile_length > 0.001:
			return profile_length
	var longest_length: float = 0.0
	if station_state != null:
		for draft_array: Array in [station_state.get("skill_drafts") as Array, station_state.get("idle_drafts") as Array]:
			for draft: Resource in draft_array:
				if draft == null:
					continue
				for node_variant: Variant in draft.get("motion_node_chain") as Array:
					var motion_node: Resource = node_variant as Resource
					if motion_node == null:
						continue
					longest_length = maxf(
						longest_length,
						(motion_node.get("tip_position_local") as Vector3).distance_to(motion_node.get("pommel_position_local") as Vector3)
					)
	return maxf(longest_length, 0.24)

func _build_preview_lines(preview_result: Dictionary, label: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	lines.append("%s_success=%s" % [label, str(bool(preview_result.get("success", false)))])
	lines.append("%s_message=%s" % [label, String(preview_result.get("message", ""))])
	lines.append("%s_source_weapon_name=%s" % [label, String(preview_result.get("source_weapon_name", ""))])
	lines.append("%s_motion_node_count=%d" % [label, int(preview_result.get("motion_node_count", 0))])
	lines.append("%s_source_equipment_slot_id=%s" % [label, String(preview_result.get("source_equipment_slot_id", StringName()))])
	return lines

func _append_activation_lines(player: PlayerController3D, label: String) -> void:
	var activation_result: Dictionary = player.get_last_skill_activation_result()
	var runtime_debug_initial: Dictionary = player.get_runtime_skill_playback_debug_state()
	var clip_debug: Dictionary = runtime_debug_initial.get("runtime_clip_debug_state", {}) as Dictionary
	result_lines.append("%s_success=%s" % [label, str(bool(activation_result.get("success", false)))])
	result_lines.append("%s_runtime_playback_started=%s" % [label, str(bool(activation_result.get("runtime_playback_started", false)))])
	result_lines.append("%s_runtime_playback_message=%s" % [label, String(activation_result.get("runtime_playback_message", ""))])
	result_lines.append("%s_source_equipment_slot_id=%s" % [label, String(activation_result.get("source_equipment_slot_id", StringName()))])
	result_lines.append("%s_runtime_active=%s" % [label, str(bool(runtime_debug_initial.get("active", false)))])
	result_lines.append("%s_runtime_clip_active=%s" % [label, str(bool(runtime_debug_initial.get("runtime_clip_active", false)))])
	result_lines.append("%s_runtime_clip_frame_count=%d" % [label, int(clip_debug.get("frame_count", 0))])
	result_lines.append("%s_runtime_clip_duration_seconds=%.4f" % [label, float(clip_debug.get("total_duration_seconds", 0.0))])
	result_lines.append("%s_runtime_compile_diagnostic_count=%d" % [label, int((runtime_debug_initial.get("runtime_compile_diagnostics", []) as Array).size())])
	result_lines.append("%s_runtime_compile_degraded_node_count=%d" % [label, int(runtime_debug_initial.get("runtime_compile_degraded_node_count", 0))])
	result_lines.append("%s_runtime_compile_retargeted_count=%d" % [label, int(runtime_debug_initial.get("runtime_compile_retargeted_count", 0))])

func _press_key(keycode: Key) -> bool:
	var key_down := InputEventKey.new()
	key_down.keycode = keycode
	key_down.physical_keycode = keycode
	key_down.pressed = true
	Input.parse_input_event(key_down)
	await process_frame
	await physics_frame
	var key_up := InputEventKey.new()
	key_up.keycode = keycode
	key_up.physical_keycode = keycode
	key_up.pressed = false
	Input.parse_input_event(key_up)
	await process_frame
	return true

func _capture_sequence_debug_snapshot(label: String) -> void:
	await process_frame
	if DisplayServer.get_name().to_lower() == "headless":
		result_lines.append("snapshot_%s=skipped_headless_display" % label)
		return
	var viewport: Viewport = root.get_viewport()
	if viewport == null:
		result_lines.append("snapshot_%s=missing_viewport" % label)
		return
	var viewport_texture: ViewportTexture = viewport.get_texture()
	if viewport_texture == null:
		result_lines.append("snapshot_%s=missing_texture" % label)
		return
	var image: Image = viewport_texture.get_image()
	if image == null or image.is_empty():
		result_lines.append("snapshot_%s=empty_image" % label)
		return
	var clean_label: String = label.replace(":", "_").replace("/", "_").replace("\\", "_")
	var path: String = "%s/%s.png" % [SEQUENCE_SNAPSHOT_DIR, clean_label]
	var save_error: Error = image.save_png(path)
	result_lines.append("snapshot_%s=%s" % [label, path if save_error == OK else "save_error_%d" % int(save_error)])

func _write_outputs() -> void:
	var result_file := FileAccess.open(SEQUENCE_RESULT_FILE_PATH, FileAccess.WRITE)
	if result_file != null:
		result_file.store_string("\n".join(result_lines))
		result_file.close()
	var sample_file := FileAccess.open(SEQUENCE_SAMPLE_FILE_PATH, FileAccess.WRITE)
	if sample_file != null:
		sample_file.store_string("\n".join(sample_lines))
		sample_file.close()
