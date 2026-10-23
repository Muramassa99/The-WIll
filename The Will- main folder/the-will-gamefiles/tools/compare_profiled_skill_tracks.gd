extends SceneTree

## Read-only comparison of two isolated Broken_Balde_v1 / Skill 1 Save results.
## --before=library.tres --after=library.tres --out=fresh_workspace_report.json
const EPSILON := 0.000001
const ANGLE_EPSILON_DEGREES := 0.0001
var _out := ""
var _report: Dictionary = {"complete": false, "drafts": {}, "tolerances": {"numeric": EPSILON, "quaternion_degrees": ANGLE_EPSILON_DEGREES}}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var options: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2: options[pair[0]] = pair[1]
	var before := _path(String(options.get("before", "")))
	var after := _path(String(options.get("after", "")))
	var output := _path(String(options.get("out", "")))
	if not output.to_lower().begins_with("c:/workspace/") or FileAccess.file_exists(output) or output.to_lower() in [before.to_lower(), after.to_lower()]:
		_finish("fresh_workspace_output_required"); return
	if not FileAccess.file_exists(before) or not FileAccess.file_exists(after):
		_finish("both_libraries_required"); return
	if DirAccess.make_dir_recursive_absolute(output.get_base_dir()) != OK:
		_finish("output_directory_failed"); return
	_out = output
	_report.merge({"before": before, "after": after, "before_sha256": FileAccess.get_sha256(before), "after_sha256": FileAccess.get_sha256(after)})
	var a := _weapon(ResourceLoader.load(before, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PlayerForgeWipLibraryState)
	var b := _weapon(ResourceLoader.load(after, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PlayerForgeWipLibraryState)
	if a == null or b == null or a.wip_id != b.wip_id:
		_finish("matching_unique_saved_weapon_required"); return
	var exact := true
	var within := true
	for label: String in ["skill_slot_1", "idle_combat"]:
		var da := _draft(a, label)
		var db := _draft(b, label)
		if da == null or db == null or not da.baked_runtime_clip is CombatRuntimeClip or not db.baked_runtime_clip is CombatRuntimeClip:
			_finish("missing_draft_or_runtime_clip_" + label); return
		var ca := da.baked_runtime_clip as CombatRuntimeClip
		var cb := db.baked_runtime_clip as CombatRuntimeClip
		var row := {"fields": {}, "before_frames": ca.get_frame_count(), "after_frames": cb.get_frame_count(),
			"before_duration": ca.total_duration_seconds, "after_duration": cb.total_duration_seconds,
			"before_sample_rate": ca.sample_rate_hz, "after_sample_rate": cb.sample_rate_hz,
			"before_nodes": da.motion_node_chain.size(), "after_nodes": db.motion_node_chain.size(),
			"both_complete_solved_tracks": _complete_track(ca) and _complete_track(cb),
			"both_60_hz": is_equal_approx(ca.sample_rate_hz, 60.0) and is_equal_approx(cb.sample_rate_hz, 60.0),
			"source_ids_match_drafts": ca.source_weapon_wip_id == a.wip_id and cb.source_weapon_wip_id == b.wip_id and ca.source_draft_id == da.draft_id and cb.source_draft_id == db.draft_id,
			"max_position_delta_m": 0.0, "max_quaternion_angle_degrees": 0.0, "max_scale_delta": 0.0}
		var left := _properties(da)
		var right := _properties(db)
		for ignored: String in ["baked_runtime_clip", "display_name", "skill_name", "skill_description", "skill_icon", "draft_notes", "selected_motion_node_index", "continuity_motion_node_index"]:
			left.erase(ignored); right.erase(ignored)
		var authored := _stats()
		_compare(left, right, "authored", authored)
		row.fields["authored"] = authored
		var ac := _properties(ca)
		var bc := _properties(cb)
		for field: String in ac:
			var stats := _stats()
			_compare(ac[field], bc.get(field), field, stats)
			row.fields[field] = stats
		row["exact_equal"] = ac.size() == bc.size()
		row["within_tolerances"] = row.both_complete_solved_tracks and row.both_60_hz and row.source_ids_match_drafts and ac.size() == bc.size()
		for stats: Dictionary in row.fields.values():
			row.exact_equal = row.exact_equal and stats.exact_equal
			row.within_tolerances = row.within_tolerances and stats.within_tolerances and stats.finite
			for metric: String in ["max_position_delta_m", "max_quaternion_angle_degrees", "max_scale_delta"]:
				row[metric] = maxf(row[metric], stats[metric])
		_report.drafts[label] = row
		exact = exact and row.exact_equal
		within = within and row.within_tolerances
	_report.merge({"exact_equal": exact, "within_tolerances": within,
		"inputs_unchanged": FileAccess.get_sha256(before) == _report.before_sha256 and FileAccess.get_sha256(after) == _report.after_sha256})
	_finish("" if within and _report.inputs_unchanged else "track_difference_or_invalid_values")

func _stats() -> Dictionary:
	return {"exact_equal": true, "within_tolerances": true, "finite": true, "mismatched_values": 0,
		"max_numeric_delta": 0.0, "max_position_delta_m": 0.0, "max_quaternion_angle_degrees": 0.0, "max_scale_delta": 0.0, "examples": []}

func _compare(a: Variant, b: Variant, path: String, stats: Dictionary) -> void:
	var kind := typeof(a)
	if kind != typeof(b):
		_mismatch(path + ":type", stats, false); return
	if a is Resource:
		_compare(_properties(a), _properties(b), path, stats); return
	if kind == TYPE_DICTIONARY:
		if a.size() != b.size(): _mismatch(path + ":size", stats, false)
		for key: Variant in a:
			if not b.has(key): _mismatch(path + ":" + str(key), stats, false)
			else: _compare(a[key], b[key], path + "." + str(key), stats)
		return
	if kind == TYPE_ARRAY or kind >= TYPE_PACKED_BYTE_ARRAY:
		if a.size() != b.size(): _mismatch(path + ":size", stats, false)
		for index: int in mini(a.size(), b.size()): _compare(a[index], b[index], "%s[%d]" % [path, index], stats)
		return
	var delta := 0.0
	var tolerance := EPSILON
	if kind == TYPE_FLOAT:
		if not is_finite(a) or not is_finite(b): stats.finite = false
		else: delta = absf(a - b)
	elif kind in [TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_QUATERNION]:
		for index: int in (2 if kind == TYPE_VECTOR2 else (3 if kind == TYPE_VECTOR3 else 4)):
			if not is_finite(a[index]) or not is_finite(b[index]): stats.finite = false
			else: delta = maxf(delta, absf(a[index] - b[index]))
		if stats.finite and (kind == TYPE_QUATERNION or (kind == TYPE_VECTOR4 and "rotation" in path)):
			var qa := Quaternion(a.x, a.y, a.z, a.w)
			var qb := Quaternion(b.x, b.y, b.z, b.w)
			if qa.length_squared() < 0.000001 or qb.length_squared() < 0.000001: stats.finite = false
			else:
				delta = 0.0 if qa == qb or qa == -qb else rad_to_deg(qa.normalized().angle_to(qb.normalized()))
				stats.max_quaternion_angle_degrees = maxf(stats.max_quaternion_angle_degrees, delta)
				tolerance = ANGLE_EPSILON_DEGREES
		elif stats.finite and kind == TYPE_VECTOR3:
			if "position" in path: stats.max_position_delta_m = maxf(stats.max_position_delta_m, a.distance_to(b))
			if "scale" in path: stats.max_scale_delta = maxf(stats.max_scale_delta, delta)
	if not stats.finite: _mismatch(path + ":nonfinite_or_invalid_quaternion", stats, false); return
	stats.max_numeric_delta = maxf(stats.max_numeric_delta, delta)
	if a != b: _mismatch(path, stats, delta <= tolerance if kind in [TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_QUATERNION] else false)

func _mismatch(path: String, stats: Dictionary, within: bool) -> void:
	stats.exact_equal = false
	stats.within_tolerances = stats.within_tolerances and within
	stats.mismatched_values += 1
	if stats.examples.size() < 8: stats.examples.append(path)

func _properties(resource: Resource) -> Dictionary:
	var result: Dictionary = {"script": resource.get_script().resource_path if resource.get_script() != null else resource.get_class()}
	for property: Dictionary in resource.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE and String(property.name) not in ["script", "resource_path", "resource_scene_unique_id", "resource_name", "resource_local_to_scene"]:
			result[String(property.name)] = resource.get(property.name)
	return result

func _complete_track(clip: CombatRuntimeClip) -> bool:
	if not clip.has_solved_replay_track() or clip.baked_solved_replay_frame_available.has(false): return false
	for index: int in clip.get_frame_count():
		for frames: Array in [clip.baked_solved_upper_body_pose_positions, clip.baked_solved_upper_body_pose_rotations, clip.baked_solved_upper_body_pose_scales]:
			if frames[index].size() != clip.baked_solved_upper_body_bone_names.size(): return false
		for frames: Array in [clip.baked_solved_anchor_positions_weapon_local, clip.baked_solved_anchor_rotations_weapon_local, clip.baked_solved_anchor_scales_weapon_local]:
			if frames[index].size() != clip.baked_solved_anchor_node_paths.size(): return false
	return true

func _weapon(library: PlayerForgeWipLibraryState) -> CraftedItemWIP:
	if library == null: return null
	var found: CraftedItemWIP
	for item: CraftedItemWIP in library.saved_wips:
		if item != null and item.forge_project_name == "Broken_Balde_v1":
			if found != null: return null
			found = item
	return found

func _draft(wip: CraftedItemWIP, identifier: String) -> CombatAnimationDraft:
	var station := wip.combat_animation_station_state as CombatAnimationStationState
	if station == null: return null
	var idle := identifier == "idle_combat"
	for draft: Resource in (station.idle_drafts if idle else station.skill_drafts):
		if draft != null and String(draft.get("context_id" if idle else "owning_skill_id")) == identifier: return draft as CombatAnimationDraft
	return null

func _path(value: String) -> String:
	return ProjectSettings.globalize_path(value).replace("\\", "/").simplify_path() if not value.is_empty() else ""

func _finish(reason: String) -> void:
	_report["complete"] = reason.is_empty()
	_report["reason"] = reason
	if not _out.is_empty():
		var file := FileAccess.open(_out, FileAccess.WRITE)
		if file == null: push_error("Cannot write comparison report."); quit(1); return
		file.store_string(JSON.stringify(_report, "\t")); file.close()
	print("PROFILE_TRACK_COMPARISON ", _out, " ", reason)
	quit(0 if reason.is_empty() else 1)
