extends SceneTree

## Compare a preserved preparation owner with the active owner on one immutable
## real-character capture. No grip optimization or production pose write runs.
const Current = preload("res://runtime/player/grip/prepared_surface_grip_anatomy.gd")
const INPUT := "C:/WORKSPACE/test_artifacts/grip_frozen_inputs_20261007_new_six/01_Handle_1_hand_right.bin"
const INPUT_SHA := "d9087b7171b82834e8ae569bc9ebdd97176afd6bbfd9816a3a78a8565b1fa1ca"
var _checks := {}
class Errors extends Logger:
	var entries: Array = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _notify: bool, kind: int, _traces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING: entries.append({"function":function,"file":file,"line":line,"code":code,"rationale":rationale})
var _errors := Errors.new()

func _init() -> void:
	OS.add_logger(_errors); call_deferred("_run")

func _run() -> void:
	var directory := OS.get_environment("THE_WILL_GRIP_PREPARATION_CLEANUP").replace("\\", "/").simplify_path()
	var prior_path := directory.path_join("prepared_surface_grip_anatomy_before.gd")
	var output_path := directory.path_join("comparison.json")
	if not directory.to_lower().begins_with("c:/workspace/test_artifacts/") or not FileAccess.file_exists(prior_path) or FileAccess.file_exists(output_path) or FileAccess.get_sha256(INPUT) != INPUT_SHA:
		push_error("Invalid preservation/input path or existing report"); quit(1); return
	var previous: Script = load(prior_path)
	if previous == null: push_error("Preserved preparation source could not load"); quit(1); return
	var file := FileAccess.open(INPUT, FileAccess.READ)
	var input: Dictionary = file.get_var(false); file.close()
	var profile: Resource = load(input.anatomy_profile)
	var anatomy: Resource = profile.get("anatomy")
	var stage: Dictionary = input.stage.duplicate(true)
	var before := var_to_bytes(stage)
	var old_owner: RefCounted = previous.new()
	var new_owner := Current.new()
	var old_prepared: Dictionary = old_owner.prepare(anatomy, stage, input.config)
	var new_prepared: Dictionary = new_owner.prepare(anatomy, stage, input.config)
	if not old_prepared.get("valid", false) or not new_prepared.get("valid", false):
		push_error("Real fixture preparation failed"); quit(1); return
	_checks["canonical_input_unchanged"] = before == var_to_bytes(stage) and FileAccess.get_sha256(INPUT) == INPUT_SHA
	_checks["new_revision_invalidates_old_geometry_cache"] = old_prepared.revision != new_prepared.revision
	var old_active := _active(old_prepared)
	var new_active := _active(new_prepared)
	_checks["all_active_data_exactly_equal"] = var_to_bytes(old_active) == var_to_bytes(new_active)
	for key: String in old_active: _checks["same_" + key] = var_to_bytes(old_active[key]) == var_to_bytes(new_active[key])
	_checks["unused_candidate_safety_removed"] = old_prepared.has("candidate_safety_samples") and not new_prepared.has("candidate_safety_samples")
	var removed := true
	for digit: StringName in Current.ALL_DIGITS:
		removed = removed and not new_prepared.digits[digit].has("candidate_safety_samples")
		for section: Dictionary in new_prepared.digits[digit].sections: removed = removed and not section.has("contact_patches")
	_checks["unused_continuous_domains_removed"] = removed
	# Both implementations use the SAME already-opened character for the timed
	# uncached geometry work. Upstream resource/skin cache warm-up is excluded.
	var timings := {"previous_geometry_ms":[], "current_geometry_ms":[]}
	for pass_index: int in 2:
		var owners: Array = [old_owner, new_owner] if pass_index == 0 else [new_owner, old_owner]
		for owner: RefCounted in owners:
			var started := Time.get_ticks_usec()
			var geometry: Dictionary = owner._prepare_geometry(new_prepared.adapter, anatomy, new_prepared.open_candidate, new_prepared.references)
			var duration := float(Time.get_ticks_usec() - started) / 1000.0
			timings["previous_geometry_ms" if owner == old_owner else "current_geometry_ms"].append(duration)
			_checks["uncached_geometry_valid_" + str(pass_index) + "_" + str(owner == old_owner)] = geometry.get("valid", false)
	var cached: Dictionary = new_owner.prepare(anatomy, stage, input.config)
	_checks["cached_active_data_equal"] = cached.get("static_preparation_cache_hit", false) and var_to_bytes(_active(cached)) == var_to_bytes(new_active)
	var report := {"schema":"surface_grip_preparation_cleanup_v1","checks":_checks,"engine_errors":_errors.entries,
		"passed":not _checks.values().has(false) and _errors.entries.is_empty(),"input_sha256":INPUT_SHA,
		"previous_source":prior_path,"previous_source_sha256":FileAccess.get_sha256(prior_path),
		"current_source_sha256":FileAccess.get_sha256("res://runtime/player/grip/prepared_surface_grip_anatomy.gd"),
		"active_projection_sha256":_digest(new_active),"sample_counts":new_prepared.sample_counts,
		"first_prepare_previous_ms":old_prepared.preparation_ms,"first_prepare_current_ms":new_prepared.preparation_ms,
		"cached_current_ms":cached.preparation_ms,"controlled_uncached_geometry_timings":timings,
		"initial_timing_caveat":"Previous full preparation runs first and may warm shared upstream caches; compare alternating geometry-only timings for removed work.",
		"solver_executed":false,"production_pose_written":false}
	file = FileAccess.open(output_path, FileAccess.WRITE); file.store_string(JSON.stringify(report, "\t")); file.close()
	print("SURFACE_GRIP_PREPARATION_CLEANUP ", "PASS" if report.passed else "FAIL", " checks=", _checks.size(), " report=", output_path)
	quit(0 if report.passed else 1)

func _active(prepared: Dictionary) -> Dictionary:
	var digits: Dictionary = prepared.digits.duplicate(true)
	for digit: StringName in digits:
		digits[digit].erase("candidate_safety_samples")
		for section: Dictionary in digits[digit].sections: section.erase("contact_patches")
	var counts: Dictionary = prepared.sample_counts.duplicate(true); counts.erase("candidate_safety")
	return {"digits":digits,"palm_samples":prepared.palm_samples,"safety_samples":prepared.safety_samples,
		"safety_triangle_ids":prepared.safety_triangle_ids,"vertices":prepared.vertices,
		"references":prepared.references,"open_frames_world":prepared.open_frames_world,
		"open_angles":prepared.open_angles,"sample_counts":counts,"selected_bones":prepared.selected_bones}

func _digest(value: Variant) -> String:
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(var_to_bytes(value)); return hash.finish().hex_encode()
