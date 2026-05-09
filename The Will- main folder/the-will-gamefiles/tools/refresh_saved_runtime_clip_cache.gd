extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const PlayerEquipmentStateScript = preload("res://core/models/player_equipment_state.gd")
const CombatAnimationDraftScript = preload("res://core/models/combat_animation_draft.gd")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const CombatAnimationRuntimeChainCompilerScript = preload("res://core/resolvers/combat_animation_runtime_chain_compiler.gd")
const CombatRuntimeClipBakerScript = preload("res://core/resolvers/combat_runtime_clip_baker.gd")
const CombatAnimationStationPreviewPresenterScript = preload("res://runtime/combat/combat_animation_station_preview_presenter.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/DEBUG-LOGS/refresh_saved_runtime_clip_cache_results.txt"
const SAMPLE_RATE_HZ := 30.0
const DEFAULT_TARGET_PROJECT_NAME := "Test sword for animations"

func _init() -> void:
	call_deferred("_run_refresh")

func _run_refresh() -> void:
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/DEBUG-LOGS")
	var lines: PackedStringArray = []
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create() as PlayerForgeWipLibraryState
	var equipment_state = PlayerEquipmentStateScript.load_or_create()
	var target_project_name: String = _resolve_target_project_name()
	var target_wip: CraftedItemWIP = _resolve_target_wip(library_state, equipment_state, target_project_name)
	var target_slot_id: StringName = _resolve_equipped_slot_id_for_wip(target_wip, equipment_state)
	var dry_run: bool = _is_dry_run()
	lines.append("library_loaded=%s" % str(library_state != null))
	lines.append("equipment_loaded=%s" % str(equipment_state != null))
	lines.append("target_project_name=%s" % target_project_name)
	lines.append("target_wip_found=%s" % str(target_wip != null))
	lines.append("dry_run=%s" % str(dry_run))
	if target_wip == null:
		_write_lines(lines)
		quit(1)
		return
	lines.append("target_wip_id=%s" % String(target_wip.wip_id))
	lines.append("target_project_label=%s" % target_wip.forge_project_name)
	lines.append("target_slot_id=%s" % String(target_slot_id))
	var refresh_result: Dictionary = await _refresh_wip_runtime_clips(target_wip, target_slot_id)
	lines.append("refresh_result=%s" % str(refresh_result))
	var persisted: bool = false
	if (
		not dry_run
		and int(refresh_result.get("cached_count", 0)) > 0
		and int(refresh_result.get("failed_count", 0)) == 0
	):
		library_state.save_wip(target_wip)
		persisted = true
	lines.append("persisted=%s" % str(persisted))
	_write_lines(lines)
	quit(0 if persisted or dry_run else 1)

func _refresh_wip_runtime_clips(target_wip: CraftedItemWIP, target_slot_id: StringName) -> Dictionary:
	var result := {
		"cached_count": 0,
		"solved_count": 0,
		"failed_count": 0,
		"results": [],
	}
	if target_wip == null:
		return result
	target_wip.ensure_combat_animation_station_state()
	var station_state: Resource = target_wip.combat_animation_station_state
	if station_state == null:
		result["failed_count"] = 1
		return result
	station_state.call("normalize")
	var preview_container := SubViewportContainer.new()
	preview_container.name = "RuntimeClipCacheRefreshPreviewContainer"
	preview_container.size = Vector2(1280, 720)
	var preview_subviewport := SubViewport.new()
	preview_subviewport.name = "RuntimeClipCacheRefreshSubViewport"
	preview_subviewport.size = Vector2i(1280, 720)
	preview_container.add_child(preview_subviewport)
	root.add_child(preview_container)
	await process_frame
	var preview_presenter = CombatAnimationStationPreviewPresenterScript.new()
	var runtime_clip_baker = CombatRuntimeClipBakerScript.new()
	var runtime_chain_compiler = CombatAnimationRuntimeChainCompilerScript.new()
	var weapon_length: float = _resolve_weapon_length_meters(target_wip, station_state)
	result["weapon_length_meters"] = weapon_length
	var drafts: Array = []
	for skill_draft: Resource in station_state.get("skill_drafts") as Array:
		if skill_draft != null:
			drafts.append(skill_draft)
	for idle_draft: Resource in station_state.get("idle_drafts") as Array:
		if idle_draft != null and StringName(idle_draft.get("context_id")) == CombatAnimationDraftScript.IDLE_CONTEXT_COMBAT:
			drafts.append(idle_draft)
	for draft: Resource in drafts:
		var draft_result: Dictionary = await _refresh_draft_runtime_clip(
			target_wip,
			draft,
			preview_container,
			preview_subviewport,
			preview_presenter,
			runtime_clip_baker,
			runtime_chain_compiler,
			weapon_length,
			target_slot_id
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

func _refresh_draft_runtime_clip(
	target_wip: CraftedItemWIP,
	draft: Resource,
	preview_container: SubViewportContainer,
	preview_subviewport: SubViewport,
	preview_presenter,
	runtime_clip_baker,
	runtime_chain_compiler,
	weapon_length: float,
	target_slot_id: StringName
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
		draft.set("baked_runtime_clip", null)
		result["reason"] = "empty_motion_node_chain"
		return result
	var draft_kind: StringName = StringName(draft.get("draft_kind"))
	var dominant_slot_id: StringName = _resolve_draft_primary_slot_id(draft, target_slot_id)
	var support_slot_id: StringName = _resolve_support_slot_id(dominant_slot_id)
	var two_hand_allowed: bool = _draft_requests_two_hand(draft)
	preview_presenter.configure_preview_hand_setup(dominant_slot_id, two_hand_allowed)
	result["dominant_slot_id"] = dominant_slot_id
	result["support_slot_id"] = support_slot_id
	result["two_hand_allowed"] = two_hand_allowed
	var equipment_context := {
		"support_hand_available": true,
		"two_hand_allowed": two_hand_allowed,
		"dominant_slot_id": dominant_slot_id,
		"support_slot_id": support_slot_id,
	}
	var compile_result: Dictionary = (
		runtime_chain_compiler.compile_idle_chain(motion_node_chain, weapon_length, {}, equipment_context)
		if draft_kind == CombatAnimationDraftScript.DRAFT_KIND_IDLE
		else runtime_chain_compiler.compile_skill_chain(motion_node_chain, weapon_length, {}, equipment_context)
	)
	var playable_chain: Array = compile_result.get("motion_node_chain", []) as Array
	if playable_chain.is_empty():
		playable_chain = motion_node_chain
	var clip_kind: StringName = &"idle" if draft_kind == CombatAnimationDraftScript.DRAFT_KIND_IDLE else &"skill_playback"
	var runtime_clip = runtime_clip_baker.bake_from_motion_node_chain(
		playable_chain,
		{
			"clip_kind": clip_kind,
			"source_draft_id": StringName(draft.get("draft_id")),
			"source_skill_slot_id": StringName(draft.get("legal_slot_id")) if draft_kind != CombatAnimationDraftScript.DRAFT_KIND_IDLE else StringName(),
			"source_idle_context_id": StringName(draft.get("context_id")) if draft_kind == CombatAnimationDraftScript.DRAFT_KIND_IDLE else StringName(),
			"source_weapon_wip_id": target_wip.wip_id,
			"source_weapon_length_meters": weapon_length,
			"playback_speed_scale": float(draft.get("preview_playback_speed_scale")),
			"loop_enabled": bool(draft.get("preview_loop_enabled")),
			"sample_rate_hz": SAMPLE_RATE_HZ,
			"trajectory_volume_config": {},
			"compile_diagnostics": compile_result.get("diagnostics", []),
			"degraded_node_count": int(compile_result.get("degraded_node_count", 0)),
			"hand_swap_bridge_count": int(compile_result.get("hand_swap_bridge_count", 0)),
			"retargeted_count": int(compile_result.get("retargeted_count", 0)),
		}
	)
	if runtime_clip == null or int(runtime_clip.call("get_frame_count")) <= 0:
		draft.set("baked_runtime_clip", null)
		result["reason"] = "runtime_clip_bake_failed"
		return result
	var selected_node_index: int = clampi(
		int(draft.get("selected_motion_node_index")),
		0,
		maxi(playable_chain.size() - 1, 0)
	)
	var pose_result: Dictionary = preview_presenter.bake_runtime_clip_upper_body_pose_track(
		preview_container,
		preview_subviewport,
		target_wip,
		draft,
		runtime_clip,
		selected_node_index
	)
	draft.set("baked_runtime_clip", runtime_clip)
	result["cached"] = true
	result["solved_replay_track"] = bool(pose_result.get("solved_replay_track", false))
	result["frame_count"] = int(runtime_clip.call("get_frame_count"))
	result["reason"] = String(pose_result.get("reason", ""))
	return result

func _resolve_target_wip(
	library_state: PlayerForgeWipLibraryState,
	equipment_state,
	target_project_name: String
) -> CraftedItemWIP:
	if library_state == null:
		return null
	var normalized_target_name: String = _normalize_project_lookup_name(target_project_name)
	if not normalized_target_name.is_empty():
		for saved_wip: CraftedItemWIP in library_state.saved_wips:
			if saved_wip == null:
				continue
			if _normalize_project_lookup_name(saved_wip.forge_project_name) == normalized_target_name:
				return saved_wip
	if equipment_state != null:
		for slot_id: StringName in [&"hand_right", &"hand_left"]:
			var equipped_entry = equipment_state.get_equipped_slot(slot_id)
			if equipped_entry == null or not equipped_entry.has_method("is_forge_test_wip") or not equipped_entry.is_forge_test_wip():
				continue
			var source_wip: CraftedItemWIP = library_state.get_saved_wip(equipped_entry.source_wip_id)
			if source_wip != null:
				return source_wip
	if library_state.selected_wip_id != StringName():
		return library_state.get_saved_wip(library_state.selected_wip_id)
	return null

func _resolve_target_project_name() -> String:
	for argument: String in OS.get_cmdline_args():
		if argument.begins_with("--target-project-name="):
			return argument.trim_prefix("--target-project-name=").strip_edges()
	return DEFAULT_TARGET_PROJECT_NAME

func _normalize_project_lookup_name(project_name: String) -> String:
	return project_name.strip_edges().to_lower().replace("_", " ")

func _resolve_equipped_slot_id_for_wip(target_wip: CraftedItemWIP, equipment_state) -> StringName:
	if target_wip != null and equipment_state != null:
		for slot_id: StringName in [&"hand_right", &"hand_left"]:
			var equipped_entry = equipment_state.get_equipped_slot(slot_id)
			if equipped_entry == null or not equipped_entry.has_method("is_forge_test_wip") or not equipped_entry.is_forge_test_wip():
				continue
			if equipped_entry.source_wip_id == target_wip.wip_id:
				return slot_id
	return &"hand_right"

func _resolve_weapon_length_meters(target_wip: CraftedItemWIP, station_state: Resource) -> float:
	if target_wip != null and target_wip.latest_baked_profile_snapshot != null:
		var profile_length: float = float(target_wip.latest_baked_profile_snapshot.weapon_total_length_meters)
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

func _resolve_draft_primary_slot_id(draft: Resource, fallback_slot_id: StringName) -> StringName:
	if draft != null:
		for node_variant: Variant in draft.get("motion_node_chain") as Array:
			var motion_node: Resource = node_variant as Resource
			if motion_node == null:
				continue
			var node_slot_id: StringName = CombatAnimationMotionNodeScript.normalize_primary_hand_slot(StringName(motion_node.get("primary_hand_slot")))
			if node_slot_id == CombatAnimationMotionNodeScript.PRIMARY_HAND_LEFT:
				return &"hand_left"
			if node_slot_id == CombatAnimationMotionNodeScript.PRIMARY_HAND_RIGHT:
				return &"hand_right"
	if fallback_slot_id == &"hand_left":
		return &"hand_left"
	return &"hand_right"

func _resolve_support_slot_id(dominant_slot_id: StringName) -> StringName:
	return &"hand_right" if dominant_slot_id == &"hand_left" else &"hand_left"

func _draft_requests_two_hand(draft: Resource) -> bool:
	if draft == null:
		return false
	if bool(draft.get("authored_for_two_hand_only")):
		return true
	for node_variant: Variant in draft.get("motion_node_chain") as Array:
		var motion_node: Resource = node_variant as Resource
		if motion_node == null:
			continue
		if StringName(motion_node.get("two_hand_state")) == CombatAnimationMotionNodeScript.TWO_HAND_STATE_TWO_HAND:
			return true
	return false

func _is_dry_run() -> bool:
	for argument: String in OS.get_cmdline_args():
		if argument == "--dry-run":
			return true
	return false

func _write_lines(lines: PackedStringArray) -> void:
	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
