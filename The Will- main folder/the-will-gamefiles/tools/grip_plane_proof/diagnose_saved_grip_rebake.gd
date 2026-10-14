extends "res://tools/grip_plane_proof/verify_surface_grip_transition_playback.gd"

## Replays the saved clip's existing raw samples through the production pose
## baker once. No Save, Idle bake, chain replacement or equipped playback.
## Uses the live preview owner's existing packet cache after natural acquisition.
## Input: THE_WILL_GRIP_LIVE_LIBRARY / THE_WILL_GRIP_LIVE_WEAPON_NAME.
## Optional stage trace: THE_WILL_GRIP_TRACE_PATH, THE_WILL_GRIP_TRACE_BAKE_FRAMES.
func _run() -> void:
	_prefix = "C:/WORKSPACE/test_artifacts/grip_saved_rebake_" + Time.get_datetime_string_from_system().replace(":", "-")
	_report = {"scope": "existing_saved_raw_clip_single_pose_rebake", "visual_grip_certified": false}
	_diagnostic_started_usec = Time.get_ticks_usec()
	create_timer(180.0, true, false, true).timeout.connect(_on_diagnostic_timeout)
	_phase("load_saved_clip")
	_source = OS.get_environment("THE_WILL_GRIP_LIVE_LIBRARY").strip_edges()
	var isolated := OS.get_environment("THE_WILL_DIAGNOSTIC_USER_ROOT").replace("\\", "/").simplify_path().to_lower()
	if not _check(_workspace(isolated) and isolated == OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower(), "incidental user writes are isolated inside workspace"):
		_finish(); return
	if not _check(_workspace(_source) and FileAccess.file_exists(_source), "saved input library is a workspace copy"):
		_finish(); return
	_source_hash = FileAccess.get_sha256(_source)
	var input: Resource = ResourceLoader.load(_source, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not _check(input != null, "saved library loads"):
		_finish(); return
	var requested := OS.get_environment("THE_WILL_GRIP_LIVE_WEAPON_NAME").strip_edges()
	var chosen: Resource
	for item: Resource in input.saved_wips:
		if item.forge_project_name == requested: chosen = item
	if not _check(chosen != null, "named saved weapon exists"):
		_finish(); return
	var source_draft: Resource
	if chosen.combat_animation_station_state != null:
		for candidate: Resource in chosen.combat_animation_station_state.skill_drafts:
			if candidate.owning_skill_id == SKILL: source_draft = candidate
	if not _check(source_draft != null and source_draft.baked_runtime_clip != null, "saved skill contains an existing clip"):
		_finish(); return
	var clip: Resource = source_draft.baked_runtime_clip.duplicate(true)
	var raw_tips: PackedVector3Array = clip.baked_tip_positions_local.duplicate()
	var raw_pommels: PackedVector3Array = clip.baked_pommel_positions_local.duplicate()
	_report.merge({"source_library": _source, "source_library_sha256": _source_hash,
		"weapon_name": requested, "frame_count": clip.get_frame_count(),
		"trace_path": OS.get_environment("THE_WILL_GRIP_TRACE_PATH")})
	if clip.has_solved_replay_track(): _report["before_continuity"] = _trajectory_continuity(clip)
	_library_player = LibraryPlayer.new()
	_library_player.library = input.duplicate(true)
	_library_player.library.save_file_path = _prefix + "_unused_library.tres"
	root.add_child(_library_player)
	_ui = UIScene.instantiate()
	root.add_child(_ui)
	await process_frame
	_phase("open_saved_selection")
	_ui.open_for(_library_player, "Isolated saved clip rebake diagnostic")
	if not _check(_ui.select_saved_wip(chosen.wip_id, true, {"dominant_slot_id": HAND, "use_two_hand": false}), "saved weapon opens"):
		_finish(); return
	_ui._on_skill_slot_selector_pressed(SKILL)
	var draft: Resource = _ui._get_active_draft()
	var selected: Resource = _ui._get_active_motion_node()
	_verified_hands.assign([selected.primary_hand_slot])
	if selected.two_hand_state == MotionData.TWO_HAND_STATE_TWO_HAND:
		_verified_hands.append(&"hand_left" if selected.primary_hand_slot == &"hand_right" else &"hand_right")
	if not await _await_grip("saved_selection"):
		_finish(); return
	var authored_before := _node_contracts(draft.motion_node_chain)
	var context: Dictionary = _ui.preview_presenter._weapon_roll_context(_ui.preview_subviewport)
	var owner: Node = context.actor.get_node("PreparedGripAcquisition")
	_report["cached_packets_before"] = owner._replay_pose_cache.size()
	_phase("single_production_pose_rebake")
	var started := Time.get_ticks_usec()
	var result: Dictionary = _ui.preview_presenter.bake_runtime_clip_upper_body_pose_track(
		_ui.preview_view_container, _ui.preview_subviewport, _ui.active_wip,
		draft, clip, draft.selected_motion_node_index)
	_report["rebake_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	_report["bake_result"] = result
	_report["cached_packets_after"] = owner._replay_pose_cache.size()
	_report["support_clamp_count"] = owner._support_motion_clamp_count
	_check(_node_contracts(draft.motion_node_chain) == authored_before, "pose rebake preserves authored nodes")
	_check(clip.baked_tip_positions_local == raw_tips and clip.baked_pommel_positions_local == raw_pommels, "pose rebake preserves raw trajectory samples")
	if _check(result.get("baked", false) and clip.has_solved_replay_track(), "single production rebake captures solved track"):
		_report["after_continuity"] = _trajectory_continuity(clip)
		var path := _prefix + "_clip.tres"
		_check(ResourceSaver.save(clip, path) == OK, "rebaked diagnostic clip writes to new workspace output")
		_report["output_clip"] = path
	_report["final_grip_status"] = _ui.preview_presenter.get_grip_acquisition_status(_ui.preview_subviewport)
	_finish()
