extends SceneTree

## Explicit promotion of a completed isolated Save profile into the real library.
## --source=... --target=... --expected-sha256=... --weapon=... --slot=... --report=...
const HandlePacket = preload("res://core/resolvers/primary_grip_handle_mesh_packet.gd")
const CombatRuntimeClipScript = preload("res://core/models/combat_runtime_clip.gd")
const SurfaceGripSolver = preload("res://runtime/player/grip/surface_driven_grip_solver.gd")
var _report_path := ""
var _report: Dictionary = {"complete": false, "persisted": false}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var options: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2: options[pair[0]] = pair[1]
	var source := _path(String(options.get("source", "")))
	var target := _path(String(options.get("target", "")))
	var report_path := _path(String(options.get("report", "")))
	var expected := String(options.get("expected-sha256", "")).to_lower()
	var weapon_name := String(options.get("weapon", "Broken_Balde_v1"))
	var slot := StringName(options.get("slot", "skill_slot_1"))
	if not report_path.to_lower().begins_with("c:/workspace/") or FileAccess.file_exists(report_path):
		_finish("fresh_workspace_report_required"); return
	if source.is_empty() or target.is_empty() or source.to_lower() == target.to_lower() or report_path.to_lower() in [source.to_lower(), target.to_lower()]:
		_finish("distinct_source_target_report_paths_required"); return
	if DirAccess.make_dir_recursive_absolute(report_path.get_base_dir()) != OK:
		_finish("report_directory_creation_failed"); return
	_report_path = report_path
	_report.merge({"source": source, "target": target, "expected_sha256": expected, "weapon": weapon_name, "slot": String(slot)})
	if expected.length() != 64 or not FileAccess.file_exists(source) or not FileAccess.file_exists(target):
		_finish("existing_libraries_and_expected_hash_required"); return
	_report["target_sha256_before"] = FileAccess.get_sha256(target)
	_report["source_sha256"] = FileAccess.get_sha256(source)
	if _report.target_sha256_before != expected:
		_finish("target_changed_since_profile_source_copy"); return
	var provenance: Variant = JSON.parse_string(FileAccess.get_file_as_string(source.get_base_dir().path_join("report.json")))
	if not provenance is Dictionary or not provenance.get("complete", false) or provenance.get("source_sha256", "") != expected:
		_finish("completed_profile_with_matching_original_hash_required"); return
	var source_library := ResourceLoader.load(source, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PlayerForgeWipLibraryState
	var target_library := ResourceLoader.load(target, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PlayerForgeWipLibraryState
	if source_library == null or target_library == null:
		_finish("library_load_failed"); return
	var profiled := _weapon(source_library, weapon_name)
	var original := _weapon(target_library, weapon_name)
	if profiled == null or original == null or profiled.wip_id != original.wip_id:
		_finish("unique_matching_weapon_id_required"); return
	var cases: Array = provenance.get("cases", [])
	if _path(String(provenance.get("output_library", ""))).to_lower() != source.to_lower() or String(provenance.get("weapon_id", "")) != String(original.wip_id) or String(provenance.get("slot", "")) != String(slot) or cases.is_empty():
		_finish("profile_report_artifact_and_ids_mismatch"); return
	var final_case: Dictionary = cases.back()
	var final_saved_path := _path(String(final_case.get("saved_library", "")))
	if not final_case.get("complete", false) or not final_case.get("ok", false) or not FileAccess.file_exists(final_saved_path) or FileAccess.get_sha256(final_saved_path) != _report.source_sha256:
		_finish("source_must_match_final_successful_profile_save"); return
	_report["profile_case"] = final_case.get("case", "")
	for item: CraftedItemWIP in target_library.saved_wips:
		if item == null or not (CraftedItemWIP.is_forge_v2_authoring_wip(item) or CraftedItemWIP.is_unarmed_authoring_wip(item)):
			_finish("native_save_would_discard_unrelated_library_entry"); return
	var geometry := _geometry_key(original)
	if geometry.is_empty() or geometry != _geometry_key(profiled):
		_finish("profile_source_weapon_geometry_mismatch"); return
	var source_station := profiled.combat_animation_station_state as CombatAnimationStationState
	var target_wip := original.duplicate(true) as CraftedItemWIP
	var station := target_wip.combat_animation_station_state as CombatAnimationStationState
	if source_station == null or station == null or source_station.station_version != CombatAnimationStationState.SKILL_BASELINE_SCHEMA_VERSION or station.station_version != CombatAnimationStationState.SKILL_BASELINE_SCHEMA_VERSION or not source_station.default_skill_package_initialized or not station.default_skill_package_initialized:
		_finish("current_station_schema_required"); return
	var skill_index := _draft_index(station.skill_drafts, &"owning_skill_id", slot)
	var idle_index := _draft_index(station.idle_drafts, &"context_id", &"idle_combat")
	var source_skill_index := _draft_index(source_station.skill_drafts, &"owning_skill_id", slot)
	var source_idle_index := _draft_index(source_station.idle_drafts, &"context_id", &"idle_combat")
	if mini(mini(skill_index, idle_index), mini(source_skill_index, source_idle_index)) < 0:
		_finish("unique_skill_and_combat_idle_drafts_required"); return
	var skill := source_station.skill_drafts[source_skill_index] as CombatAnimationDraft
	var idle := source_station.idle_drafts[source_idle_index] as CombatAnimationDraft
	if skill == null or skill.draft_kind != CombatAnimationDraft.DRAFT_KIND_SKILL or skill.legal_slot_id != slot or skill.motion_node_chain.size() != 21:
		_finish("twenty_visible_nodes_plus_hidden_node_zero_required"); return
	if idle == null or idle.draft_kind != CombatAnimationDraft.DRAFT_KIND_IDLE:
		_finish("combat_idle_draft_kind_required"); return
	if not _complete_clip(skill, original.wip_id) or not _complete_clip(idle, original.wip_id):
		_finish("complete_skill_and_idle_solved_tracks_required"); return
	if idle.preferred_grip_style_mode != original.grip_style_mode:
		_finish("native_save_would_change_profiled_idle_grip_style"); return
	if not is_equal_approx(skill.get_total_transition_duration_seconds(), 20.0):
		_finish("twenty_second_profile_required"); return
	for index: int in range(1, 21):
		var node := skill.motion_node_chain[index] as CombatAnimationMotionNode
		if node == null or node.generated_transition_node or not is_equal_approx(node.transition_duration_seconds, 1.0):
			_finish("twenty_authored_one_second_nodes_required"); return
	if original.forge_project_notes != original.forge_project_notes.strip_edges():
		_finish("native_save_would_trim_existing_weapon_notes"); return
	var imported_skill := skill.duplicate(true) as CombatAnimationDraft
	var imported_idle := idle.duplicate(true) as CombatAnimationDraft
	for field: StringName in [&"display_name", &"skill_name", &"skill_description", &"skill_icon", &"draft_notes"]:
		imported_skill.set(field, station.skill_drafts[skill_index].get(field))
		imported_idle.set(field, station.idle_drafts[idle_index].get(field))
	station.skill_drafts[skill_index] = imported_skill
	station.idle_drafts[idle_index] = imported_idle
	# Mirror native save's preparation on a disposable clone before any write.
	var original_id := String(original.wip_id)
	if original_id.is_empty() or original_id.begins_with("debug_") or original_id.begins_with("draft_"):
		_finish("native_save_would_replace_weapon_id"); return
	var normalized := target_wip.duplicate(true) as CraftedItemWIP
	normalized.forge_project_name = target_library.call("_resolve_forge_project_name", normalized)
	normalized.forge_project_notes = target_library.call("_resolve_forge_project_notes", normalized)
	normalized.stow_position_mode = CraftedItemWIP.normalize_stow_position_mode(normalized.stow_position_mode)
	normalized.grip_style_mode = CraftedItemWIP.resolve_supported_grip_style(normalized.grip_style_mode, normalized.forge_intent, normalized.equipment_context)
	normalized.ensure_combat_animation_station_state()
	var changed_path := _first_difference(target_wip, normalized, "weapon")
	if not changed_path.is_empty():
		_report["changed_path"] = changed_path
		_finish("native_save_preparation_would_change_preserved_data"); return
	_report["normalization_preserves_prepared_weapon"] = true
	_report.merge({"weapon_id": String(original.wip_id), "visible_nodes": 20, "hidden_entry_nodes": 1,
		"raw_nodes": 21, "duration_seconds": skill.get_total_transition_duration_seconds(),
		"skill_frames": skill.baked_runtime_clip.get_frame_count(), "idle_frames": idle.baked_runtime_clip.get_frame_count(),
		"preserved_weapon_default_grip_style": String(original.grip_style_mode), "library_wip_count": target_library.saved_wips.size()})
	var backup := report_path.get_basename() + "_before_%d.tres" % Time.get_ticks_usec()
	if FileAccess.file_exists(backup) or FileAccess.get_sha256(target) != expected:
		_finish("target_changed_or_backup_exists"); return
	if DirAccess.copy_absolute(target, backup) != OK or FileAccess.get_sha256(backup) != expected:
		_finish("verified_backup_failed"); return
	_report["backup"] = backup
	if FileAccess.get_sha256(target) != expected or FileAccess.get_sha256(source) != _report.source_sha256:
		_finish("library_changed_before_write"); return
	target_library.save_file_path = target
	target_library.trace_save_latency = true
	var saved := target_library.save_wip(target_wip)
	_report["persisted"] = bool(target_library.last_save_latency_trace.get("success", false))
	_report["target_sha256_after"] = FileAccess.get_sha256(target)
	if saved == null:
		_finish("native_save_wip_failed"); return
	var reloaded := ResourceLoader.load(target, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PlayerForgeWipLibraryState
	changed_path = _first_difference(target_library, reloaded, "library")
	if not changed_path.is_empty():
		_report["changed_path"] = changed_path
		_finish("saved_library_values_changed_on_reload"); return
	var verified := _weapon(reloaded, weapon_name)
	if verified == null or reloaded.saved_wips.size() != int(_report.library_wip_count) or verified.wip_id != original.wip_id or _geometry_key(verified) != geometry:
		_finish("saved_weapon_reload_mismatch"); return
	var saved_station := verified.combat_animation_station_state as CombatAnimationStationState
	var saved_skill_index := _draft_index(saved_station.skill_drafts, &"owning_skill_id", slot)
	var saved_idle_index := _draft_index(saved_station.idle_drafts, &"context_id", &"idle_combat")
	if mini(saved_skill_index, saved_idle_index) < 0:
		_finish("saved_unique_skill_and_idle_required"); return
	var saved_skill := saved_station.skill_drafts[saved_skill_index] as CombatAnimationDraft
	var saved_idle := saved_station.idle_drafts[saved_idle_index] as CombatAnimationDraft
	if not _complete_clip(saved_skill, original.wip_id) or not _complete_clip(saved_idle, original.wip_id) or saved_skill.owning_skill_id != slot or saved_skill.motion_node_chain.size() != 21:
		_finish("saved_solved_tracks_or_slot_mismatch"); return
	if saved_skill.runtime_cache_signature != skill.runtime_cache_signature or saved_idle.runtime_cache_signature != idle.runtime_cache_signature or not is_equal_approx(saved_skill.get_total_transition_duration_seconds(), 20.0) or saved_skill.baked_runtime_clip.get_frame_count() != int(_report.skill_frames) or saved_idle.baked_runtime_clip.get_frame_count() != int(_report.idle_frames):
		_finish("saved_skill_timing_or_cache_mismatch"); return
	if verified.forge_project_notes != original.forge_project_notes or verified.grip_style_mode != original.grip_style_mode or saved_skill.skill_description != imported_skill.skill_description:
		_finish("saved_notes_or_default_grip_style_mismatch"); return
	_report["reload_verified"] = true
	_finish()

func _weapon(library: PlayerForgeWipLibraryState, requested: String) -> CraftedItemWIP:
	if library == null: return null
	var found: CraftedItemWIP
	for item: CraftedItemWIP in library.saved_wips:
		if item != null and (item.forge_project_name == requested or String(item.wip_id) == requested):
			if found != null: return null
			found = item
	return found

func _draft_index(drafts: Array[Resource], field: StringName, identifier: StringName) -> int:
	var found := -1
	for index: int in drafts.size():
		if drafts[index] != null and StringName(drafts[index].get(field)) == identifier:
			if found >= 0: return -1
			found = index
	return found

func _complete_clip(draft: CombatAnimationDraft, weapon_id: StringName) -> bool:
	if draft == null or draft.runtime_cache_signature.is_empty(): return false
	# Same cache revision gate as PlayerEquippedSkillSlotPresenter.
	var fields := draft.runtime_cache_signature.split("|", false, 2)
	if fields.size() < 2 or not CombatRuntimeClipScript.COMPATIBLE_RUNTIME_CACHE_VERSIONS.has(fields[0]) or fields[1] != String(SurfaceGripSolver.REVISION): return false
	var clip := draft.baked_runtime_clip as CombatRuntimeClip
	if clip == null or clip.schema_version != CombatRuntimeClip.SCHEMA_VERSION or not clip.has_solved_replay_track() or clip.source_weapon_wip_id != weapon_id or clip.source_draft_id != draft.draft_id: return false
	if &"PrimaryGripAnchor" not in clip.baked_solved_anchor_node_paths: return false
	if draft.draft_kind == CombatAnimationDraft.DRAFT_KIND_SKILL and clip.source_skill_slot_id != draft.owning_skill_id: return false
	if draft.draft_kind == CombatAnimationDraft.DRAFT_KIND_IDLE and clip.source_idle_context_id != draft.context_id: return false
	for index: int in clip.get_frame_count():
		if not clip.baked_solved_replay_frame_available[index]: return false
		for frames: Array in [clip.baked_solved_upper_body_pose_positions, clip.baked_solved_upper_body_pose_rotations, clip.baked_solved_upper_body_pose_scales]:
			if frames[index].size() != clip.baked_solved_upper_body_bone_names.size(): return false
		for frames: Array in [clip.baked_solved_anchor_positions_weapon_local, clip.baked_solved_anchor_rotations_weapon_local, clip.baked_solved_anchor_scales_weapon_local]:
			if frames[index].size() != clip.baked_solved_anchor_node_paths.size(): return false
	return is_equal_approx(clip.total_duration_seconds, draft.get_total_transition_duration_seconds())

func _first_difference(a: Variant, b: Variant, path: String, seen: Dictionary = {}) -> String:
	if typeof(a) != typeof(b): return path
	if a is Resource and b is Resource:
		var pair := "%s:%s" % [a.get_instance_id(), b.get_instance_id()]
		if seen.has(pair): return ""
		seen[pair] = true
		var a_script: Script = a.get_script()
		var b_script: Script = b.get_script()
		if a.get_class() != b.get_class() or (a_script.resource_path if a_script != null else "") != (b_script.resource_path if b_script != null else ""): return path + ".script"
		for property: Dictionary in a.get_property_list():
			var name := String(property.name)
			if not (int(property.usage) & PROPERTY_USAGE_STORAGE) or name in ["script", "resource_path", "resource_scene_unique_id"]: continue
			var difference := _first_difference(a.get(name), b.get(name), path + "." + name, seen)
			if not difference.is_empty(): return difference
		return ""
	if a is Array or a is Dictionary:
		if a.size() != b.size(): return path + ".size"
		for key: Variant in (a.keys() if a is Dictionary else range(a.size())):
			if a is Dictionary and not b.has(key): return path + "." + str(key)
			var difference := _first_difference(a[key], b[key], path + "." + str(key), seen)
			if not difference.is_empty(): return difference
		return ""
	return "" if a == b else path

func _geometry_key(wip: CraftedItemWIP) -> String:
	var state: Resource = wip.forge_v2_authoring_state
	var profile := wip.latest_baked_profile_snapshot
	if state == null or profile == null: return ""
	var values: Array = [profile.weapon_total_length_meters, profile.weapon_tip_point, profile.weapon_pommel_point,
		profile.primary_grip_span_start, profile.primary_grip_span_end, profile.primary_grip_slice_axis_ratios_from_span_start, profile.primary_grip_slice_centers]
	for body: Resource in state.get("material_bodies"):
		if body == null: return ""
		values.append([body.get("body_id"), body.get("material_variant_id"), body.get("operation_mode"), HandlePacket.build_body_signature(body)])
	return var_to_bytes(values).hex_encode().sha256_text()

func _path(value: String) -> String:
	if value.is_empty(): return ""
	return ProjectSettings.globalize_path(value).replace("\\", "/").simplify_path()

func _finish(reason: String = "") -> void:
	_report["complete"] = reason.is_empty()
	_report["reason"] = reason
	if not _report_path.is_empty():
		var file := FileAccess.open(_report_path, FileAccess.WRITE)
		if file == null: push_error("Cannot write publication report."); quit(1); return
		file.store_string(JSON.stringify(_report, "\t"))
		file.close()
	print("PROFILE_PUBLICATION ", JSON.stringify(_report))
	quit(0 if reason.is_empty() else 1)
