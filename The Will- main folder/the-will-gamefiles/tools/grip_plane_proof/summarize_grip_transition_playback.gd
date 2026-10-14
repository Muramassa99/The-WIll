extends "res://tools/grip_plane_proof/verify_surface_grip_transition_playback.gd"

## Read recorded clips only. No preview, grip solve, bake or source-library save.
## THE_WILL_GRIP_TRANSITION_SAVED_LIBRARY must point at a workspace .tres copy.
func _run() -> void:
	_diagnostic_started_usec = Time.get_ticks_usec()
	_prefix = "C:/WORKSPACE/test_artifacts/grip_transition_continuity_" + Time.get_datetime_string_from_system().replace(":", "-")
	_report = {"scope": "read_only_existing_grip_transition_clip_continuity", "visual_grip_certified": false}
	_source = OS.get_environment("THE_WILL_GRIP_TRANSITION_SAVED_LIBRARY").strip_edges()
	if not _check(_workspace(_source) and FileAccess.file_exists(_source), "saved clip library is an existing workspace copy"):
		_finish(); return
	_source_hash = FileAccess.get_sha256(_source)
	_report["source_library"] = _source
	_report["source_library_sha256"] = _source_hash
	var library: Resource = ResourceLoader.load(_source, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not _check(library != null, "existing saved clip library loads"):
		_finish(); return
	var clips: Array = []
	for item: Resource in library.saved_wips:
		if item.combat_animation_station_state == null: continue
		for draft: Resource in item.combat_animation_station_state.skill_drafts:
			var clip: Resource = draft.baked_runtime_clip
			if clip == null or not clip.has_solved_replay_track(): continue
			var has_style_bridge := false
			for node: Resource in clip.motion_node_chain:
				if node.generated_transition_kind == MotionData.TRANSITION_KIND_GRIP_STYLE_SWAP:
					has_style_bridge = true
			if not has_style_bridge: continue
			clips.append({"weapon": item.forge_project_name, "draft_id": draft.draft_id,
				"clip_id": clip.clip_id, "continuity": _trajectory_continuity(clip)})
	_report["clips"] = clips
	_check(not clips.is_empty(), "at least one recorded real grip-style transition was inspected")
	_finish()
