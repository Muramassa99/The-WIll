extends SceneTree

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const PlayerEquipmentStateScript = preload("res://core/models/player_equipment_state.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const PlayerSkillSlotStateScript = preload("res://core/models/player_skill_slot_state.gd")
const CombatAnimationStationStateScript = preload("res://core/models/combat_animation_station_state.gd")
const CombatAnimationDraftScript = preload("res://core/models/combat_animation_draft.gd")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const CombatAnimationRuntimeChainCompilerScript = preload("res://core/resolvers/combat_animation_runtime_chain_compiler.gd")
const CombatRuntimeClipBakerScript = preload("res://core/resolvers/combat_runtime_clip_baker.gd")
const CombatAnimationStationPreviewPresenterScript = preload("res://runtime/combat/combat_animation_station_preview_presenter.gd")
const CombatAnimationChainPlayerScript = preload("res://runtime/combat/combat_animation_chain_player.gd")
const WeaponGripAnchorProviderScript = preload("res://runtime/player/weapon_grip_anchor_provider.gd")
const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/bridge_origin_replay_comparator_results.txt"
const SAMPLE_FILE_PATH := "C:/WORKSPACE/bridge_origin_replay_comparator_samples.csv"
const TEMP_LIBRARY_SAVE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_bridge_origin_replay_comparator_library.tres"
const TEMP_SKILL_SLOT_SAVE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_bridge_origin_replay_comparator_slots.tres"
const TEMP_EQUIPMENT_SAVE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_bridge_origin_replay_comparator_equipment.tres"

const DOMINANT_SLOT_ID: StringName = &"hand_right"
const SUPPORT_SLOT_ID: StringName = &"hand_left"
const SKILL_SLOT_ID: StringName = &"skill_slot_3"
const RL_BONE_ROOT_NAME := "RL_BoneRoot"
const SAMPLE_STEP_SECONDS := 1.0 / 60.0
const DRIFT_THRESHOLD_METERS := 0.02
const ROTATION_DRIFT_THRESHOLD_DEGREES := 2.0

var result_lines := PackedStringArray()
var sample_lines := PackedStringArray()
var weapon_grip_anchor_provider = WeaponGripAnchorProviderScript.new()

func _init() -> void:
	call_deferred("_run_diagnostic")

func _run_diagnostic() -> void:
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/test_artifacts")
	_reset_outputs()
	result_lines.append("diagnostic=bridge_origin_replay_comparator")
	result_lines.append("machine_origin_bone=%s" % RL_BONE_ROOT_NAME)
	result_lines.append("dominant_slot_id=%s" % String(DOMINANT_SLOT_ID))
	result_lines.append("skill_slot_id=%s" % String(SKILL_SLOT_ID))
	sample_lines.append(
		"sample_index,elapsed_seconds,runtime_clip_elapsed_seconds,phase,hidden_bridge_kind,hidden_bridge_active,solved_available,solved_bridge_frame,source_available,source_time_seconds,runtime_weapon_pos_mcs,applied_weapon_pos_mcs,source_weapon_pos_mcs,final_weapon_pos_mcs,authority_root_pos_mcs,final_weapon_pos_authority_local,runtime_to_applied_weapon_error_m,applied_to_final_weapon_error_m,runtime_to_final_weapon_error_m,runtime_to_authority_local_weapon_error_m,source_to_runtime_weapon_error_m,runtime_to_final_primary_anchor_error_m,primary_grip_alignment_error_m,weapon_rotation_error_deg,applied_bridge_anchor_lock_slot,runtime_endpoint_active,upper_body_authoring_active,authority_root_valid,held_parent"
	)

	var authored_wip: CraftedItemWIP = _build_authored_comparator_wip()
	var station_state: CombatAnimationStationState = authored_wip.ensure_combat_animation_station_state() as CombatAnimationStationState
	var skill_draft: CombatAnimationDraft = station_state.get_or_create_skill_draft(
		SKILL_SLOT_ID,
		"Bridge Comparator Skill",
		authored_wip.grip_style_mode,
		SKILL_SLOT_ID
	) as CombatAnimationDraft
	var source_clip = await _bake_skill_crafter_source_clip(authored_wip, skill_draft)
	result_lines.append("source_clip_exists=%s" % str(source_clip != null))
	result_lines.append("source_clip_solved_replay_track=%s" % str(_clip_has_solved_replay(source_clip)))
	result_lines.append("source_clip_frame_count=%d" % _clip_frame_count(source_clip))
	result_lines.append("source_clip_duration_seconds=%.5f" % _clip_duration(source_clip))
	result_lines.append("source_clip_reference_origin_id=%s" % String(source_clip.get("solved_replay_reference_origin_id") if source_clip != null else StringName()))
	if source_clip == null or not _clip_has_solved_replay(source_clip):
		_write_outputs()
		quit(1)
		return

	skill_draft.baked_runtime_clip = source_clip
	skill_draft.normalize()
	station_state.normalize()

	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	library_state.save_file_path = TEMP_LIBRARY_SAVE_PATH
	library_state.saved_wips.clear()
	var saved_wip: CraftedItemWIP = library_state.save_wip(authored_wip)

	var equipment_state: PlayerEquipmentState = PlayerEquipmentStateScript.new()
	equipment_state.save_file_path = TEMP_EQUIPMENT_SAVE_PATH
	equipment_state.equip_forge_test_wip(DOMINANT_SLOT_ID, saved_wip)

	var skill_slot_state: PlayerSkillSlotState = PlayerSkillSlotStateScript.new()
	skill_slot_state.save_file_path = TEMP_SKILL_SLOT_SAVE_PATH
	skill_slot_state.slot_assignments.clear()

	var player: PlayerController3D = PlayerScene.instantiate() as PlayerController3D
	player.equipment_state = equipment_state
	player.forge_wip_library_state = library_state
	player.player_skill_slot_state = skill_slot_state
	player.weapons_drawn = true
	root.add_child(player)
	await _wait_frames(4)
	player.call("_sync_equipped_test_meshes")
	player.call("_sync_equipped_skill_slots")
	await _wait_frames(4)

	var preview_result: Dictionary = player.preview_runtime_skill_slot_activation(SKILL_SLOT_ID)
	result_lines.append("preview_success=%s" % str(bool(preview_result.get("success", false))))
	result_lines.append("preview_message=%s" % String(preview_result.get("message", "")))
	result_lines.append("preview_motion_node_count=%d" % int(preview_result.get("motion_node_count", 0)))
	player.call("_activate_skill_slot", SKILL_SLOT_ID)
	var activation_result: Dictionary = player.get_last_skill_activation_result()
	var runtime_debug_initial: Dictionary = player.get_runtime_skill_playback_debug_state()
	var runtime_clip = player.runtime_skill_playback_presenter.active_runtime_clip
	var runtime_duration: float = _clip_duration(runtime_clip)
	var source_duration: float = _clip_duration(source_clip)
	var entry_bridge_duration: float = float(runtime_debug_initial.get("entry_bridge_duration_seconds", 0.0))
	var observe_seconds: float = maxf(runtime_duration + 0.45, entry_bridge_duration + source_duration + 0.45)
	result_lines.append("activation_success=%s" % str(bool(activation_result.get("success", false))))
	result_lines.append("runtime_started=%s" % str(bool(activation_result.get("runtime_playback_started", false))))
	result_lines.append("runtime_message=%s" % String(activation_result.get("runtime_playback_message", "")))
	result_lines.append("runtime_clip_exists=%s" % str(runtime_clip != null))
	result_lines.append("runtime_clip_solved_replay_track=%s" % str(_clip_has_solved_replay(runtime_clip)))
	result_lines.append("runtime_clip_frame_count=%d" % _clip_frame_count(runtime_clip))
	result_lines.append("runtime_clip_duration_seconds=%.5f" % runtime_duration)
	result_lines.append("source_clip_frame_summary=%s" % _build_clip_frame_summary(source_clip))
	result_lines.append("runtime_clip_frame_summary=%s" % _build_clip_frame_summary(runtime_clip))
	result_lines.append("runtime_clip_bridge_flag_summary=%s" % _build_bridge_flag_summary(runtime_clip))
	result_lines.append("entry_bridge_active=%s" % str(bool(runtime_debug_initial.get("entry_bridge_active", false))))
	result_lines.append("entry_bridge_duration_seconds=%.5f" % entry_bridge_duration)
	result_lines.append("observe_seconds=%.5f" % observe_seconds)

	var stats := {
		"sample_count": 0,
		"max_runtime_to_final_weapon_error": 0.0,
		"max_runtime_to_applied_weapon_error": 0.0,
		"max_applied_to_final_weapon_error": 0.0,
		"max_source_to_runtime_weapon_error": 0.0,
		"max_runtime_to_final_primary_anchor_error": 0.0,
		"max_weapon_rotation_error_degrees": 0.0,
		"first_runtime_to_final_weapon_drift": "",
		"first_runtime_to_applied_weapon_drift": "",
		"first_applied_to_final_weapon_drift": "",
		"first_source_to_runtime_weapon_drift": "",
		"first_primary_anchor_drift": "",
		"first_weapon_rotation_drift": "",
	}
	var sample_times: Array[float] = _build_sample_times(entry_bridge_duration, source_duration, runtime_duration, observe_seconds)
	var elapsed := 0.0
	var sample_index := 0
	_capture_sample(player, source_clip, elapsed, entry_bridge_duration, sample_index, stats)
	sample_index += 1
	for sample_time: float in sample_times:
		if sample_time <= 0.00001:
			continue
		while elapsed + 0.00001 < sample_time:
			await physics_frame
			await process_frame
			elapsed += SAMPLE_STEP_SECONDS
		_capture_sample(player, source_clip, elapsed, entry_bridge_duration, sample_index, stats)
		sample_index += 1
	while elapsed + 0.00001 < observe_seconds:
		await physics_frame
		await process_frame
		elapsed += SAMPLE_STEP_SECONDS
		if sample_index % 15 == 0:
			_capture_sample(player, source_clip, elapsed, entry_bridge_duration, sample_index, stats)
		sample_index += 1

	result_lines.append("sample_count=%d" % int(stats.get("sample_count", 0)))
	result_lines.append("max_runtime_to_final_weapon_error_m=%.6f" % float(stats.get("max_runtime_to_final_weapon_error", 0.0)))
	result_lines.append("max_runtime_to_applied_weapon_error_m=%.6f" % float(stats.get("max_runtime_to_applied_weapon_error", 0.0)))
	result_lines.append("max_applied_to_final_weapon_error_m=%.6f" % float(stats.get("max_applied_to_final_weapon_error", 0.0)))
	result_lines.append("max_source_to_runtime_weapon_error_m=%.6f" % float(stats.get("max_source_to_runtime_weapon_error", 0.0)))
	result_lines.append("max_runtime_to_final_primary_anchor_error_m=%.6f" % float(stats.get("max_runtime_to_final_primary_anchor_error", 0.0)))
	result_lines.append("max_weapon_rotation_error_degrees=%.4f" % float(stats.get("max_weapon_rotation_error_degrees", 0.0)))
	result_lines.append("first_runtime_to_final_weapon_drift=%s" % String(stats.get("first_runtime_to_final_weapon_drift", "")))
	result_lines.append("first_runtime_to_applied_weapon_drift=%s" % String(stats.get("first_runtime_to_applied_weapon_drift", "")))
	result_lines.append("first_applied_to_final_weapon_drift=%s" % String(stats.get("first_applied_to_final_weapon_drift", "")))
	result_lines.append("first_source_to_runtime_weapon_drift=%s" % String(stats.get("first_source_to_runtime_weapon_drift", "")))
	result_lines.append("first_primary_anchor_drift=%s" % String(stats.get("first_primary_anchor_drift", "")))
	result_lines.append("first_weapon_rotation_drift=%s" % String(stats.get("first_weapon_rotation_drift", "")))
	result_lines.append("interpretation=%s" % _build_interpretation(stats))
	_write_outputs()
	quit(0)

func _build_authored_comparator_wip() -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIPScript.new()
	wip.wip_id = &"bridge_origin_replay_comparator_weapon"
	wip.forge_project_name = "Bridge Origin Replay Comparator Weapon"
	wip.creator_id = &"diagnostic"
	wip.created_timestamp = Time.get_unix_time_from_system()
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	var layer_a: LayerAtom = LayerAtom.new()
	layer_a.layer_index = 20
	layer_a.cells = _build_handle_cells(20)
	var layer_b: LayerAtom = LayerAtom.new()
	layer_b.layer_index = 21
	layer_b.cells = _build_handle_cells(21)
	wip.layers = [layer_a, layer_b]
	var station_state: CombatAnimationStationState = wip.ensure_combat_animation_station_state() as CombatAnimationStationState
	var draft: CombatAnimationDraft = station_state.get_or_create_skill_draft(
		SKILL_SLOT_ID,
		"Bridge Comparator Skill",
		wip.grip_style_mode,
		SKILL_SLOT_ID
	) as CombatAnimationDraft
	draft.skill_name = "Bridge Comparator Skill"
	draft.preview_loop_enabled = false
	draft.preview_playback_speed_scale = 1.0
	draft.motion_node_chain = [
		_build_motion_node(0, Vector3(0.18, 0.18, -0.46), Vector3(-0.08, -0.04, 0.22), Vector3(0.0, -12.0, 4.0), 0.26),
		_build_motion_node(1, Vector3(0.38, 0.08, -0.42), Vector3(0.02, -0.12, 0.20), Vector3(2.0, -36.0, -8.0), 0.34),
		_build_motion_node(2, Vector3(0.10, 0.26, -0.34), Vector3(-0.22, -0.02, 0.18), Vector3(-8.0, 18.0, 16.0), 0.34),
	]
	draft.selected_motion_node_index = 0
	draft.normalize()
	station_state.normalize()
	return wip

func _build_motion_node(
	index: int,
	tip_position: Vector3,
	pommel_position: Vector3,
	orientation_degrees: Vector3,
	transition_seconds: float
) -> CombatAnimationMotionNode:
	var node: CombatAnimationMotionNode = CombatAnimationMotionNodeScript.new()
	node.node_index = index
	node.node_id = StringName("bridge_comparator_node_%02d" % index)
	node.tip_position_local = tip_position
	node.tip_position_origin_id = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	node.pommel_position_local = pommel_position
	node.pommel_position_origin_id = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	node.weapon_orientation_degrees = orientation_degrees
	node.weapon_orientation_authored = true
	node.weapon_roll_degrees = 8.0 - float(index) * 7.0
	node.body_support_blend = 0.3 + float(index) * 0.15
	node.right_upperarm_roll_degrees = 4.0 + float(index) * 8.0
	node.left_upperarm_roll_degrees = -2.0 - float(index) * 4.0
	node.two_hand_state = CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND
	node.primary_hand_slot = CombatAnimationMotionNodeScript.PRIMARY_HAND_RIGHT
	node.preferred_grip_style_mode = &"grip_normal"
	node.transition_duration_seconds = transition_seconds
	node.normalize()
	return node

func _bake_skill_crafter_source_clip(active_wip: CraftedItemWIP, draft: CombatAnimationDraft):
	if active_wip == null or draft == null:
		return null
	var runtime_chain_compiler = CombatAnimationRuntimeChainCompilerScript.new()
	var runtime_clip_baker = CombatRuntimeClipBakerScript.new()
	var preview_presenter = CombatAnimationStationPreviewPresenterScript.new()
	var equipment_context := {
		"support_hand_available": true,
		"two_hand_allowed": true,
		"dominant_slot_id": DOMINANT_SLOT_ID,
		"support_slot_id": SUPPORT_SLOT_ID,
	}
	var weapon_length: float = _resolve_weapon_length_from_draft(draft)
	var compile_result: Dictionary = runtime_chain_compiler.compile_skill_chain(
		draft.motion_node_chain,
		weapon_length,
		{},
		equipment_context
	)
	result_lines.append("source_compile_compiled=%s" % str(bool(compile_result.get("compiled", false))))
	result_lines.append("source_compile_diagnostic_count=%d" % int((compile_result.get("diagnostics", []) as Array).size()))
	result_lines.append("source_compile_retargeted_count=%d" % int(compile_result.get("retargeted_count", 0)))
	var playable_chain: Array = compile_result.get("motion_node_chain", draft.motion_node_chain) as Array
	if playable_chain.is_empty():
		return null
	var runtime_clip = runtime_clip_baker.bake_from_motion_node_chain(
		playable_chain,
		{
			"clip_kind": &"skill_playback",
			"source_draft_id": draft.draft_id,
			"source_skill_slot_id": SKILL_SLOT_ID,
			"source_weapon_wip_id": active_wip.wip_id,
			"source_weapon_length_meters": weapon_length,
			"playback_speed_scale": draft.preview_playback_speed_scale,
			"loop_enabled": false,
			"trajectory_volume_config": {},
			"compile_diagnostics": compile_result.get("diagnostics", []),
			"degraded_node_count": int(compile_result.get("degraded_node_count", 0)),
			"hand_swap_bridge_count": int(compile_result.get("hand_swap_bridge_count", 0)),
			"retargeted_count": int(compile_result.get("retargeted_count", 0)),
		}
	)
	if runtime_clip == null or not runtime_clip.is_playable():
		return null
	var preview_container := SubViewportContainer.new()
	preview_container.name = "BridgeComparatorPreviewContainer"
	preview_container.size = Vector2(1280, 720)
	var preview_subviewport := SubViewport.new()
	preview_subviewport.name = "BridgeComparatorPreviewSubViewport"
	preview_subviewport.size = Vector2i(1280, 720)
	preview_container.add_child(preview_subviewport)
	root.add_child(preview_container)
	await process_frame
	var pose_result: Dictionary = preview_presenter.bake_runtime_clip_upper_body_pose_track(
		preview_container,
		preview_subviewport,
		active_wip,
		draft,
		runtime_clip,
		draft.selected_motion_node_index
	)
	result_lines.append("source_pose_baked=%s" % str(bool(pose_result.get("baked", false))))
	result_lines.append("source_pose_reason=%s" % String(pose_result.get("reason", "")))
	result_lines.append("source_pose_solved_replay_track=%s" % str(bool(pose_result.get("solved_replay_track", false))))
	result_lines.append("source_pose_bone_count=%d" % int(pose_result.get("bone_count", 0)))
	result_lines.append("source_pose_anchor_count=%d" % int(pose_result.get("anchor_count", 0)))
	result_lines.append("source_pose_primary_anchor_to_anatomical_grip_max_m=%.6f" % float(pose_result.get("primary_anchor_to_anatomical_grip_max_meters", -1.0)))
	preview_container.queue_free()
	return runtime_clip

func _capture_sample(
	player: PlayerController3D,
	source_clip,
	elapsed_seconds: float,
	entry_bridge_duration: float,
	sample_index: int,
	stats: Dictionary
) -> void:
	var held_item: Node3D = player.held_item_nodes.get(DOMINANT_SLOT_ID) as Node3D if player != null else null
	var humanoid_rig: Node3D = player.humanoid_rig if player != null else null
	var skeleton: Skeleton3D = _resolve_skeleton(humanoid_rig)
	var machine_transform: Transform3D = _resolve_machine_transform(skeleton, humanoid_rig)
	var machine_inverse: Transform3D = machine_transform.affine_inverse()
	var runtime_debug: Dictionary = player.get_runtime_skill_playback_debug_state()
	var idle_debug: Dictionary = player.get_runtime_idle_pose_debug_state()
	var skill_active: bool = bool(runtime_debug.get("active", false))
	var idle_active: bool = bool(idle_debug.get("active", false))
	var phase := "runtime_skill" if skill_active else ("runtime_idle" if idle_active else "none")
	var chain_player = (
		player.runtime_skill_playback_presenter.chain_player
		if skill_active
		else player.runtime_skill_playback_presenter.idle_chain_player
	)
	var hidden_bridge: Dictionary = runtime_debug.get("hidden_bridge_state", {}) as Dictionary
	var pose_state: Dictionary = (
		runtime_debug.get("last_runtime_pose_state", {}) as Dictionary
		if skill_active
		else idle_debug.get("last_runtime_idle_pose_state", {}) as Dictionary
	)
	var runtime_clip_elapsed: float = _resolve_chain_clip_elapsed(chain_player, elapsed_seconds)
	var runtime_state: Dictionary = _capture_chain_solved_state(chain_player)
	var applied_state: Dictionary = _capture_applied_solved_replay_weapon_state(humanoid_rig)
	var source_time: float = clampf(runtime_clip_elapsed - entry_bridge_duration, 0.0, _clip_duration(source_clip))
	var source_state: Dictionary = _sample_clip_solved_state(source_clip, source_time)
	var final_state: Dictionary = _capture_final_scene_state(held_item, humanoid_rig, machine_inverse, runtime_state)
	var runtime_applied_error: float = _distance_if_valid(
		runtime_state.get("weapon_position", Vector3.ZERO) as Vector3,
		applied_state.get("weapon_position", Vector3.ZERO) as Vector3,
		bool(runtime_state.get("available", false)) and bool(applied_state.get("available", false))
	)
	var applied_final_error: float = _distance_if_valid(
		applied_state.get("weapon_position", Vector3.ZERO) as Vector3,
		final_state.get("weapon_position", Vector3.ZERO) as Vector3,
		bool(applied_state.get("available", false)) and bool(final_state.get("valid", false))
	)
	var runtime_weapon_error: float = _distance_if_valid(
		runtime_state.get("weapon_position", Vector3.ZERO) as Vector3,
		final_state.get("weapon_position", Vector3.ZERO) as Vector3,
		bool(runtime_state.get("available", false)) and bool(final_state.get("valid", false))
	)
	var runtime_authority_local_error: float = _distance_if_valid(
		runtime_state.get("weapon_position", Vector3.ZERO) as Vector3,
		final_state.get("weapon_position_authority_local", Vector3.ZERO) as Vector3,
		bool(runtime_state.get("available", false)) and bool(final_state.get("authority_root_valid", false))
	)
	var source_runtime_error: float = _distance_if_valid(
		source_state.get("weapon_position", Vector3.ZERO) as Vector3,
		runtime_state.get("weapon_position", Vector3.ZERO) as Vector3,
		bool(source_state.get("available", false)) and bool(runtime_state.get("available", false)) and runtime_clip_elapsed >= entry_bridge_duration - 0.0001
	)
	var primary_anchor_error: float = _distance_if_valid(
		runtime_state.get("primary_anchor_position", Vector3.ZERO) as Vector3,
		final_state.get("primary_anchor_position", Vector3.ZERO) as Vector3,
		bool(runtime_state.get("primary_anchor_available", false)) and bool(final_state.get("primary_anchor_available", false))
	)
	var rotation_error_degrees: float = _rotation_error_degrees_if_valid(
		runtime_state.get("weapon_rotation", Quaternion.IDENTITY) as Quaternion,
		final_state.get("weapon_rotation", Quaternion.IDENTITY) as Quaternion,
		bool(runtime_state.get("available", false)) and bool(final_state.get("valid", false))
	)
	var primary_grip_alignment_error: float = float(pose_state.get("primary_grip_alignment_error_meters", -1.0))
	var bridge_anchor_lock_active: bool = StringName(applied_state.get("bridge_anchor_lock_slot_id", StringName())) != StringName()
	_update_stats(
		stats,
		sample_index,
		elapsed_seconds,
		phase,
		-1.0 if bridge_anchor_lock_active else runtime_weapon_error,
		runtime_applied_error,
		-1.0 if bridge_anchor_lock_active else applied_final_error,
		source_runtime_error,
		-1.0 if bridge_anchor_lock_active else primary_anchor_error,
		rotation_error_degrees
	)
	sample_lines.append("%d,%.5f,%.5f,%s,%s,%s,%s,%s,%s,%.5f,%s,%s,%s,%s,%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.4f,%s,%s,%s,%s,%s" % [
		sample_index,
		elapsed_seconds,
		runtime_clip_elapsed,
		phase,
		String(hidden_bridge.get("kind", StringName())),
		str(bool(hidden_bridge.get("active", false))),
		str(bool(runtime_state.get("available", false))),
		str(bool(runtime_state.get("bridge_frame", false))),
		str(bool(source_state.get("available", false))),
		source_time,
		_format_vector(runtime_state.get("weapon_position", Vector3.ZERO) as Vector3),
		_format_vector(applied_state.get("weapon_position", Vector3.ZERO) as Vector3),
		_format_vector(source_state.get("weapon_position", Vector3.ZERO) as Vector3),
		_format_vector(final_state.get("weapon_position", Vector3.ZERO) as Vector3),
		_format_vector(final_state.get("authority_root_position", Vector3.ZERO) as Vector3),
		_format_vector(final_state.get("weapon_position_authority_local", Vector3.ZERO) as Vector3),
		runtime_applied_error,
		applied_final_error,
		runtime_weapon_error,
		runtime_authority_local_error,
		source_runtime_error,
		primary_anchor_error,
		primary_grip_alignment_error,
		rotation_error_degrees,
		String(applied_state.get("bridge_anchor_lock_slot_id", StringName())),
		str(bool(pose_state.get("runtime_endpoint_authority_active", false))),
		str(_upper_body_authoring_active(humanoid_rig)),
		str(bool(final_state.get("authority_root_valid", false))),
		String(final_state.get("held_parent", ""))
	])

func _capture_chain_solved_state(chain_player) -> Dictionary:
	var state := {
		"available": false,
		"bridge_frame": false,
		"weapon_position": Vector3.ZERO,
		"weapon_rotation": Quaternion.IDENTITY,
		"weapon_scale": Vector3.ONE,
		"primary_anchor_available": false,
		"primary_anchor_local": Vector3.INF,
		"primary_anchor_position": Vector3.ZERO,
	}
	if chain_player == null:
		return state
	state["available"] = bool(chain_player.current_solved_replay_available)
	state["bridge_frame"] = bool(chain_player.current_solved_replay_bridge_frame)
	state["weapon_position"] = chain_player.current_solved_weapon_position_reference_local
	state["weapon_rotation"] = chain_player.current_solved_weapon_rotation_reference_local
	state["weapon_scale"] = chain_player.current_solved_weapon_scale_reference_local
	var weapon_transform: Transform3D = _build_transform(
		state["weapon_position"] as Vector3,
		state["weapon_rotation"] as Quaternion,
		state["weapon_scale"] as Vector3
	)
	var primary_anchor_local: Vector3 = _resolve_primary_anchor_local(
		chain_player.current_solved_anchor_node_paths,
		chain_player.current_solved_anchor_positions_weapon_local
	)
	if primary_anchor_local != Vector3.INF:
		state["primary_anchor_available"] = true
		state["primary_anchor_local"] = primary_anchor_local
		state["primary_anchor_position"] = weapon_transform * primary_anchor_local
	return state

func _sample_clip_solved_state(clip, time_seconds: float) -> Dictionary:
	if clip == null or not _clip_has_solved_replay(clip):
		return {"available": false}
	var sampler = CombatAnimationChainPlayerScript.new()
	sampler.prepare_runtime_clip(clip, 1.0, false)
	sampler.start()
	if time_seconds > 0.000001:
		sampler.advance(time_seconds)
	return _capture_chain_solved_state(sampler)

func _capture_applied_solved_replay_weapon_state(humanoid_rig: Node3D) -> Dictionary:
	var state := {
		"available": false,
		"weapon_position": Vector3.ZERO,
		"weapon_rotation": Quaternion.IDENTITY,
		"weapon_scale": Vector3.ONE,
		"bridge_anchor_lock_slot_id": StringName(),
	}
	if humanoid_rig == null:
		return state
	var replay_state_variant: Variant = humanoid_rig.get("runtime_solved_replay_weapon_state")
	if not (replay_state_variant is Dictionary):
		return state
	var replay_state: Dictionary = replay_state_variant as Dictionary
	if replay_state.is_empty() or not bool(replay_state.get("active", false)):
		return state
	state["available"] = true
	state["weapon_position"] = replay_state.get("weapon_position_reference_local", Vector3.ZERO) as Vector3
	state["weapon_rotation"] = replay_state.get("weapon_rotation_reference_local", Quaternion.IDENTITY) as Quaternion
	state["weapon_scale"] = replay_state.get("weapon_scale_reference_local", Vector3.ONE) as Vector3
	state["bridge_anchor_lock_slot_id"] = StringName(replay_state.get("bridge_anchor_lock_slot_id", StringName()))
	return state

func _capture_final_scene_state(
	held_item: Node3D,
	humanoid_rig: Node3D,
	machine_inverse: Transform3D,
	runtime_state: Dictionary
) -> Dictionary:
	var state := {
		"valid": false,
		"weapon_position": Vector3.ZERO,
		"weapon_rotation": Quaternion.IDENTITY,
		"primary_anchor_available": false,
		"primary_anchor_position": Vector3.ZERO,
		"authority_root_valid": false,
		"authority_root_position": Vector3.ZERO,
		"weapon_position_authority_local": Vector3.ZERO,
		"held_parent": "",
	}
	if held_item == null or not is_instance_valid(held_item):
		return state
	var weapon_mcs: Transform3D = machine_inverse * held_item.global_transform
	state["valid"] = true
	state["weapon_position"] = weapon_mcs.origin
	state["weapon_rotation"] = weapon_mcs.basis.orthonormalized().get_rotation_quaternion().normalized()
	state["held_parent"] = str(held_item.get_parent().get_path() if held_item.get_parent() != null else NodePath(""))
	var authority_root: Node3D = humanoid_rig.get_node_or_null("RuntimeCombatEndpointAuthorityRoot") as Node3D if humanoid_rig != null else null
	if authority_root != null and is_instance_valid(authority_root):
		var authority_root_mcs: Transform3D = machine_inverse * authority_root.global_transform
		var weapon_authority_transform: Transform3D = authority_root.global_transform.affine_inverse() * held_item.global_transform
		state["authority_root_valid"] = true
		state["authority_root_position"] = authority_root_mcs.origin
		state["weapon_position_authority_local"] = weapon_authority_transform.origin
	var primary_anchor: Node3D = weapon_grip_anchor_provider.get_primary_grip_anchor(held_item)
	if primary_anchor != null and is_instance_valid(primary_anchor):
		var primary_anchor_mcs: Transform3D = machine_inverse * primary_anchor.global_transform
		state["primary_anchor_available"] = true
		state["primary_anchor_position"] = primary_anchor_mcs.origin
	elif bool(runtime_state.get("primary_anchor_available", false)):
		var fallback_anchor_mcs: Vector3 = (machine_inverse * held_item.global_transform) * _resolve_primary_anchor_local_from_state(runtime_state)
		state["primary_anchor_available"] = true
		state["primary_anchor_position"] = fallback_anchor_mcs
	return state

func _update_stats(
	stats: Dictionary,
	sample_index: int,
	elapsed_seconds: float,
	phase: String,
	runtime_weapon_error: float,
	runtime_applied_error: float,
	applied_final_error: float,
	source_runtime_error: float,
	primary_anchor_error: float,
	rotation_error_degrees: float
) -> void:
	stats["sample_count"] = int(stats.get("sample_count", 0)) + 1
	if runtime_weapon_error >= 0.0 and runtime_weapon_error > float(stats.get("max_runtime_to_final_weapon_error", 0.0)):
		stats["max_runtime_to_final_weapon_error"] = runtime_weapon_error
	if runtime_applied_error >= 0.0 and runtime_applied_error > float(stats.get("max_runtime_to_applied_weapon_error", 0.0)):
		stats["max_runtime_to_applied_weapon_error"] = runtime_applied_error
	if applied_final_error >= 0.0 and applied_final_error > float(stats.get("max_applied_to_final_weapon_error", 0.0)):
		stats["max_applied_to_final_weapon_error"] = applied_final_error
	if source_runtime_error >= 0.0 and source_runtime_error > float(stats.get("max_source_to_runtime_weapon_error", 0.0)):
		stats["max_source_to_runtime_weapon_error"] = source_runtime_error
	if primary_anchor_error >= 0.0 and primary_anchor_error > float(stats.get("max_runtime_to_final_primary_anchor_error", 0.0)):
		stats["max_runtime_to_final_primary_anchor_error"] = primary_anchor_error
	if rotation_error_degrees >= 0.0 and rotation_error_degrees > float(stats.get("max_weapon_rotation_error_degrees", 0.0)):
		stats["max_weapon_rotation_error_degrees"] = rotation_error_degrees
	if String(stats.get("first_runtime_to_final_weapon_drift", "")).is_empty() and runtime_weapon_error > DRIFT_THRESHOLD_METERS:
		stats["first_runtime_to_final_weapon_drift"] = _format_drift(sample_index, elapsed_seconds, phase, runtime_weapon_error)
	if String(stats.get("first_runtime_to_applied_weapon_drift", "")).is_empty() and runtime_applied_error > DRIFT_THRESHOLD_METERS:
		stats["first_runtime_to_applied_weapon_drift"] = _format_drift(sample_index, elapsed_seconds, phase, runtime_applied_error)
	if String(stats.get("first_applied_to_final_weapon_drift", "")).is_empty() and applied_final_error > DRIFT_THRESHOLD_METERS:
		stats["first_applied_to_final_weapon_drift"] = _format_drift(sample_index, elapsed_seconds, phase, applied_final_error)
	if String(stats.get("first_source_to_runtime_weapon_drift", "")).is_empty() and source_runtime_error > DRIFT_THRESHOLD_METERS:
		stats["first_source_to_runtime_weapon_drift"] = _format_drift(sample_index, elapsed_seconds, phase, source_runtime_error)
	if String(stats.get("first_primary_anchor_drift", "")).is_empty() and primary_anchor_error > DRIFT_THRESHOLD_METERS:
		stats["first_primary_anchor_drift"] = _format_drift(sample_index, elapsed_seconds, phase, primary_anchor_error)
	if String(stats.get("first_weapon_rotation_drift", "")).is_empty() and rotation_error_degrees > ROTATION_DRIFT_THRESHOLD_DEGREES:
		stats["first_weapon_rotation_drift"] = _format_drift(sample_index, elapsed_seconds, phase, rotation_error_degrees)

func _build_interpretation(stats: Dictionary) -> String:
	var source_runtime_drift: String = String(stats.get("first_source_to_runtime_weapon_drift", ""))
	var runtime_applied_drift: String = String(stats.get("first_runtime_to_applied_weapon_drift", ""))
	var applied_final_drift: String = String(stats.get("first_applied_to_final_weapon_drift", ""))
	var final_drift: String = String(stats.get("first_runtime_to_final_weapon_drift", ""))
	var anchor_drift: String = String(stats.get("first_primary_anchor_drift", ""))
	if not source_runtime_drift.is_empty():
		return "runtime_replay_data_diverges_from_skill_crafter_source"
	if not runtime_applied_drift.is_empty():
		return "presenter_chain_replay_diverges_before_rig_application"
	if not applied_final_drift.is_empty():
		return "rig_applied_replay_state_drifts_during_scene_application_or_bridge_anchor_lock"
	if not final_drift.is_empty() or not anchor_drift.is_empty():
		return "runtime_replay_data_matches_source_after_entry_but_final_scene_application_drifts"
	return "runtime_replay_source_and_final_scene_remain_within_threshold"

func _resolve_skeleton(humanoid_rig: Node3D) -> Skeleton3D:
	if humanoid_rig == null:
		return null
	return humanoid_rig.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D

func _resolve_machine_transform(skeleton: Skeleton3D, humanoid_rig: Node3D) -> Transform3D:
	if skeleton != null:
		var bone_index: int = skeleton.find_bone(RL_BONE_ROOT_NAME)
		if bone_index >= 0:
			var world_pose: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bone_index)
			return Transform3D(world_pose.basis.orthonormalized(), world_pose.origin)
	if humanoid_rig != null:
		return humanoid_rig.global_transform
	return Transform3D.IDENTITY

func _resolve_primary_anchor_local(anchor_paths: Array, anchor_positions: Array) -> Vector3:
	for anchor_index: int in range(anchor_paths.size()):
		if String(anchor_paths[anchor_index]) != "PrimaryGripAnchor":
			continue
		if anchor_index >= anchor_positions.size():
			return Vector3.INF
		return anchor_positions[anchor_index] as Vector3
	return Vector3.INF

func _resolve_primary_anchor_local_from_state(state: Dictionary) -> Vector3:
	var value: Variant = state.get("primary_anchor_local", Vector3.INF)
	return value as Vector3 if value is Vector3 else Vector3.INF

func _build_transform(position: Vector3, rotation: Quaternion, scale: Vector3) -> Transform3D:
	var basis := Basis(rotation.normalized())
	basis = basis.scaled(scale)
	return Transform3D(basis, position)

func _distance_if_valid(a: Vector3, b: Vector3, valid: bool) -> float:
	return a.distance_to(b) if valid else -1.0

func _rotation_error_degrees_if_valid(a: Quaternion, b: Quaternion, valid: bool) -> float:
	return rad_to_deg(a.normalized().angle_to(b.normalized())) if valid else -1.0

func _upper_body_authoring_active(humanoid_rig: Node3D) -> bool:
	if humanoid_rig == null or not humanoid_rig.has_method("get_upper_body_authoring_state"):
		return false
	var state: Dictionary = humanoid_rig.call("get_upper_body_authoring_state") as Dictionary
	return bool(state.get("active", false))

func _resolve_chain_clip_elapsed(chain_player, fallback_elapsed_seconds: float) -> float:
	if chain_player == null:
		return fallback_elapsed_seconds
	var elapsed_variant: Variant = chain_player.get("_clip_elapsed")
	if elapsed_variant is float or elapsed_variant is int:
		return float(elapsed_variant)
	return fallback_elapsed_seconds

func _build_sample_times(entry_bridge_duration: float, source_duration: float, runtime_duration: float, observe_seconds: float) -> Array[float]:
	var times: Array[float] = [
		0.0,
		maxf(entry_bridge_duration * 0.25, SAMPLE_STEP_SECONDS),
		maxf(entry_bridge_duration * 0.5, SAMPLE_STEP_SECONDS),
		maxf(entry_bridge_duration - SAMPLE_STEP_SECONDS, SAMPLE_STEP_SECONDS),
		entry_bridge_duration + SAMPLE_STEP_SECONDS,
		entry_bridge_duration + source_duration * 0.25,
		entry_bridge_duration + source_duration * 0.5,
		entry_bridge_duration + source_duration * 0.75,
		maxf(runtime_duration - SAMPLE_STEP_SECONDS, 0.0),
		runtime_duration + SAMPLE_STEP_SECONDS,
		observe_seconds,
	]
	var unique: Array[float] = []
	for time_value: float in times:
		var clean_time: float = clampf(time_value, 0.0, observe_seconds)
		var exists := false
		for existing: float in unique:
			if absf(existing - clean_time) <= 0.0001:
				exists = true
				break
		if not exists:
			unique.append(clean_time)
	unique.sort()
	return unique

func _resolve_weapon_length_from_draft(draft: CombatAnimationDraft) -> float:
	var longest := 0.0
	if draft != null:
		for node_variant: Variant in draft.motion_node_chain:
			var motion_node: CombatAnimationMotionNode = node_variant as CombatAnimationMotionNode
			if motion_node == null:
				continue
			longest = maxf(longest, motion_node.tip_position_local.distance_to(motion_node.pommel_position_local))
	return maxf(longest, 0.24)

func _build_handle_cells(layer_index: int) -> Array[CellAtom]:
	var cells: Array[CellAtom] = []
	for x in range(20, 48):
		for y in range(10, 13):
			var cell: CellAtom = CellAtom.new()
			cell.grid_position = Vector3i(x, y, layer_index)
			cell.layer_index = layer_index
			cell.material_variant_id = &"mat_wood_gray"
			cells.append(cell)
	return cells

func _clip_has_solved_replay(clip) -> bool:
	return clip != null and clip.has_method("has_solved_replay_track") and bool(clip.call("has_solved_replay_track"))

func _clip_frame_count(clip) -> int:
	return int(clip.call("get_frame_count")) if clip != null and clip.has_method("get_frame_count") else 0

func _clip_duration(clip) -> float:
	if clip == null:
		return 0.0
	var duration: float = float(clip.get("total_duration_seconds"))
	if duration > 0.0:
		return duration
	var frame_times: PackedFloat32Array = clip.get("baked_frame_times") as PackedFloat32Array
	return float(frame_times[frame_times.size() - 1]) if not frame_times.is_empty() else 0.0

func _build_clip_frame_summary(clip) -> String:
	if clip == null:
		return "missing"
	var frame_times: PackedFloat32Array = clip.get("baked_frame_times") as PackedFloat32Array
	var weapon_positions: PackedVector3Array = clip.get("baked_solved_weapon_positions_reference_local") as PackedVector3Array
	var parts := PackedStringArray()
	var count: int = mini(frame_times.size(), weapon_positions.size())
	var limit: int = mini(count, 8)
	for frame_index: int in range(limit):
		parts.append("%d@%.3f:%s" % [
			frame_index,
			float(frame_times[frame_index]),
			_format_vector(weapon_positions[frame_index]),
		])
	if count > limit:
		parts.append("...%d_frames" % count)
	return ";".join(parts)

func _build_bridge_flag_summary(clip) -> String:
	if clip == null or not clip.has_meta("baked_solved_replay_bridge_frame"):
		return "missing"
	var frame_times: PackedFloat32Array = clip.get("baked_frame_times") as PackedFloat32Array
	var flags: Array = clip.get_meta("baked_solved_replay_bridge_frame") as Array
	var parts := PackedStringArray()
	var count: int = mini(frame_times.size(), flags.size())
	var limit: int = mini(count, 16)
	for frame_index: int in range(limit):
		parts.append("%d@%.3f:%s" % [
			frame_index,
			float(frame_times[frame_index]),
			"bridge" if bool(flags[frame_index]) else "authored",
		])
	if count > limit:
		parts.append("...%d_flags" % count)
	return ";".join(parts)

func _format_vector(value: Vector3) -> String:
	return "%.5f|%.5f|%.5f" % [value.x, value.y, value.z]

func _format_drift(sample_index: int, elapsed_seconds: float, phase: String, value: float) -> String:
	return "sample:%d time:%.5f phase:%s value:%.6f" % [sample_index, elapsed_seconds, phase, value]

func _wait_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await process_frame
		await physics_frame

func _reset_outputs() -> void:
	result_lines.clear()
	sample_lines.clear()

func _write_outputs() -> void:
	var result_file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if result_file != null:
		result_file.store_string("\n".join(result_lines))
		result_file.close()
	var sample_file := FileAccess.open(SAMPLE_FILE_PATH, FileAccess.WRITE)
	if sample_file != null:
		sample_file.store_string("\n".join(sample_lines))
		sample_file.close()
	for line in result_lines:
		print(line)
