extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationDraftScript = preload("res://core/models/combat_animation_draft.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/DEBUG-LOGS/diagnose_saved_runtime_clip_cache_results.txt"
const TARGET_PROJECT_NAME := "Test sword for animations"

func _init() -> void:
	call_deferred("_run_diagnostic")

func _run_diagnostic() -> void:
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/DEBUG-LOGS")
	var lines: PackedStringArray = []
	var library_state = PlayerForgeWipLibraryStateScript.load_or_create()
	var target_wip: CraftedItemWIP = _find_target_wip(library_state)
	lines.append("library_loaded=%s" % str(library_state != null))
	lines.append("target_project_name=%s" % TARGET_PROJECT_NAME)
	lines.append("target_wip_found=%s" % str(target_wip != null))
	if target_wip != null:
		lines.append("target_wip_id=%s" % String(target_wip.wip_id))
		lines.append("target_project_label=%s" % target_wip.forge_project_name)
		var station_state: Resource = target_wip.ensure_combat_animation_station_state()
		lines.append("station_state_found=%s" % str(station_state != null))
		if station_state != null:
			station_state.call("normalize")
			_append_draft_lines(lines, station_state.get("skill_drafts") as Array, "skill")
			_append_draft_lines(lines, station_state.get("idle_drafts") as Array, "idle")
	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit(0)

func _append_draft_lines(lines: PackedStringArray, drafts: Array, label: String) -> void:
	for draft_variant: Variant in drafts:
		var draft: Resource = draft_variant as Resource
		if draft == null:
			continue
		var runtime_clip: Resource = draft.get("baked_runtime_clip") as Resource
		var frame_count: int = int(runtime_clip.call("get_frame_count")) if runtime_clip != null and runtime_clip.has_method("get_frame_count") else 0
		var has_solved_replay: bool = runtime_clip != null and runtime_clip.has_method("has_solved_replay_track") and bool(runtime_clip.call("has_solved_replay_track"))
		var has_upper_body_pose: bool = runtime_clip != null and runtime_clip.has_method("has_upper_body_pose_track") and bool(runtime_clip.call("has_upper_body_pose_track"))
		var source: StringName = runtime_clip.get("solved_replay_track_source") as StringName if runtime_clip != null else StringName()
		var reference_bone: StringName = runtime_clip.get("solved_replay_reference_bone_name") as StringName if runtime_clip != null else StringName()
		var solved_bone_count: int = (runtime_clip.get("baked_solved_upper_body_bone_names") as Array).size() if runtime_clip != null else 0
		var solved_anchor_count: int = (runtime_clip.get("baked_solved_anchor_node_paths") as Array).size() if runtime_clip != null else 0
		var available_count: int = 0
		if runtime_clip != null:
			for available_variant: Variant in runtime_clip.get("baked_solved_replay_frame_available") as Array:
				if bool(available_variant):
					available_count += 1
		lines.append(
			"%s_draft id=%s slot=%s context=%s frame_count=%d upper_body_pose=%s solved_replay=%s solved_available=%d solved_bones=%d solved_anchors=%d source=%s reference=%s" % [
				label,
				String(draft.get("draft_id")),
				String(draft.get("legal_slot_id")),
				String(draft.get("context_id")),
				frame_count,
				str(has_upper_body_pose),
				str(has_solved_replay),
				available_count,
				solved_bone_count,
				solved_anchor_count,
				String(source),
				String(reference_bone),
			]
		)

func _find_target_wip(library_state) -> CraftedItemWIP:
	if library_state == null:
		return null
	for saved_wip: CraftedItemWIP in library_state.saved_wips:
		if saved_wip == null:
			continue
		if _normalize_project_lookup_name(saved_wip.forge_project_name) == _normalize_project_lookup_name(TARGET_PROJECT_NAME):
			return saved_wip
	if library_state.selected_wip_id != StringName():
		return library_state.get_saved_wip(library_state.selected_wip_id)
	return null

func _normalize_project_lookup_name(project_name: String) -> String:
	return project_name.strip_edges().to_lower().replace("_", " ")
