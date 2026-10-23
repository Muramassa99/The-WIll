extends SceneTree

## Offline audit of a frozen diagnostic report. No scenes, assets or saves are
## loaded. --source=<absolute report.json> --out=<new absolute sidecar.json>
var _checks: int = 0
var _failures: Array[String] = []
var _accepted: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var options: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var pair: PackedStringArray = argument.substr(2).split("=", true, 1)
			options[pair[0]] = pair[1]
	var source: String = String(options.get("source", "")).replace("\\", "/").simplify_path()
	var output: String = String(options.get("out", "")).replace("\\", "/").simplify_path()
	if not source.is_absolute_path() or not output.is_absolute_path() \
			or not source.to_lower().begins_with("c:/workspace/") or not output.to_lower().begins_with("c:/workspace/") \
			or source.to_lower() == output.to_lower() or not FileAccess.file_exists(source) or FileAccess.file_exists(output):
		push_error("Expected an existing workspace --source and a distinct new workspace --out.")
		quit(2)
		return
	var source_hash: String = FileAccess.get_sha256(source)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(source))
	if not parsed is Dictionary:
		push_error("Source report is not a JSON object.")
		quit(2)
		return
	var report: Dictionary = parsed
	var steps: Array = report.get("steps", [])
	var saved: Dictionary = {}
	var observed: Dictionary = {}
	for step: Dictionary in steps:
		var label: String = String(step.get("step", ""))
		observed[label] = step
		if label == "explicit_Save_and_reload":
			_check(saved.is_empty(), "only_one_Save_row")
			saved = step
		else:
			_check(bool(step.get("ok", false)), "recorded_step_passed:" + label)
	_check(not saved.is_empty(), "Save_row_present")
	for required: String in ["twenty_prime", "twenty_append", "twenty_latest_edit", "cancel_sampling_camera", "cancel_busy_camera",
			"twenty_middle_duration_edit", "nineteen_middle_delete", "twenty_middle_R_reinsert"]:
		_check(observed.has(required) and bool(observed[required].get("ok", false)), "long_regression:" + required)
	_check(int((observed.get("twenty_middle_R_reinsert", {}) as Dictionary).get("visible_nodes", -1)) == 20, "final_visible_node_count_20")
	for field: String in ["F_solved_fast_path", "active_cache_retained_before_Save", "active_clip_same_resource",
			"authored_unchanged_before_Save", "cached_F_started", "combat_idle_uncached_before_Save", "dirty_cleared",
			"idle_prepared", "no_auto_playback", "output_file_exists", "source_unchanged", "stopped_before_Save"]:
		_check(saved.has(field) and saved[field] == true, "Save_contract:" + field)
	var exempt: Array[String] = ["ok", "authored_chain_equal", "idle_authored_chain_equal", "authored_text_roundtrip_equivalent", "idle_authored_text_roundtrip_equivalent"]
	for field: Variant in saved:
		if typeof(saved[field]) == TYPE_BOOL and not exempt.has(String(field)):
			_check(saved[field], "all_other_Save_booleans:" + String(field))
	for field: String in ["before", "before_Save_persistence"]:
		var persistence: Dictionary = saved.get(field, {})
		_check(bool(persistence.get("ok", false)) and bool(persistence.get("source_unchanged", false))
			and bool(persistence.get("output_unchanged", false)), "no_earlier_write:" + field)
	_check(String(saved.get("output_sha256", "missing")) != "missing"
		and String(saved.get("output_sha256", "")) != String(report.get("initial_output_sha256", "")), "Save_wrote_output")
	_check(String(saved.get("save_message", "")).contains("Preview ready"), "Save_reported_ready")
	for field: String in ["active_clip_preservation", "reload_comparison", "idle_reload_comparison"]:
		var comparison: Dictionary = saved.get(field, {})
		_check(bool(comparison.get("ok", false)) and int(comparison.get("fields_checked", 0)) == 66
			and (comparison.get("differences", ["missing"]) as Array).is_empty(), "all_66_fields_exact:" + field)
	for group_name: String in ["authored_chain_differences", "idle_authored_chain_differences"]:
		var group: Dictionary = saved.get(group_name, {})
		for phase: String in ["before_to_live", "live_to_persisted_clone"]:
			var exact: Dictionary = group.get(phase, {})
			_check(bool(exact.get("exact_equal", false)) and not bool(exact.get("truncated", true))
				and (exact.get("differences", ["missing"]) as Array).is_empty(), group_name + ":exact:" + phase)
		for phase: String in ["before_to_reloaded", "live_to_reloaded", "persisted_clone_to_reloaded"]:
			_audit_differences(group.get(phase, {}), group_name + ":" + phase)
	_check(FileAccess.get_sha256(source) == source_hash, "frozen_report_unchanged")
	var sidecar: Dictionary = {"verifier": "incremental_saved_metadata_report", "source": source,
		"source_sha256": source_hash, "checks": _checks, "ok": _failures.is_empty(), "failures": _failures,
		"accepted_metadata_differences": _accepted,
		"scope": "Offline re-evaluation of recorded long-motion and Save evidence; no engine replay or lifecycle cases rerun. Original report unchanged."}
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Could not create sidecar report.")
		quit(2)
		return
	file.store_string(JSON.stringify(sidecar, "\t"))
	file.close()
	print(JSON.stringify({"verifier": sidecar.verifier, "checks": _checks, "ok": sidecar.ok, "failures": _failures, "out": output}))
	quit(0 if _failures.is_empty() else 1)

func _audit_differences(comparison: Dictionary, label: String) -> void:
	var differences: Array = comparison.get("differences", [])
	_check(not comparison.is_empty() and not bool(comparison.get("truncated", true)), label + ":complete_differences")
	_check(int(comparison.get("reported_differences", -1)) == differences.size(), label + ":difference_count")
	for difference: Dictionary in differences:
		var path: String = String(difference.get("path", ""))
		var lhs: Dictionary = difference.get("left", {})
		var rhs: Dictionary = difference.get("right", {})
		var left_hex: String = String(lhs.get("variant_bytes_hex", ""))
		var right_hex: String = String(rhs.get("variant_bytes_hex", ""))
		if left_hex.is_empty() or right_hex.is_empty():
			_check(false, label + ":missing_exact_bytes:" + path)
			continue
		var left: Variant = bytes_to_var(left_hex.hex_decode())
		var right: Variant = bytes_to_var(right_hex.hex_decode())
		var exact_bytes: bool = typeof(left) == TYPE_FLOAT and typeof(right) == TYPE_FLOAT \
			and var_to_bytes(left).hex_encode() == left_hex and var_to_bytes(right).hex_encode() == right_hex
		_check(exact_bytes, label + ":decode_exact_scalars:" + path)
		var accepted: bool = exact_bytes and _allowed_metadata_roundtrip(path, left, right)
		_check(accepted, label + ":allowed_metadata_roundtrip:" + path)
		if accepted:
			_accepted.append({"comparison": label, "path": path, "left_bytes": left_hex, "right_bytes": right_hex,
				"serialized_left": var_to_str(left), "error": absf(float(left) - float(right))})
			_check(not _allowed_metadata_roundtrip(path + ".unrelated", left, right), label + ":unrelated_field_rejected:" + path)
			_check(not _allowed_metadata_roundtrip(path, left, float(right) + 0.01), label + ":changed_value_rejected:" + path)

func _allowed_metadata_roundtrip(path: String, left: Variant, right: Variant) -> bool:
	if typeof(left) != TYPE_FLOAT or typeof(right) != TYPE_FLOAT or not is_finite(left) or not is_finite(right): return false
	if path.ends_with(".retarget_node.source_weapon_length_meters"):
		var original_float32: float = PackedFloat32Array([left])[0]
		return left == original_float32 and original_float32 == float(PackedFloat32Array([right])[0])
	if path.ends_with(".retarget_node.pivot_range_percent"):
		var text_roundtrip: Variant = str_to_var(var_to_str(left))
		return typeof(text_roundtrip) == TYPE_FLOAT and text_roundtrip == right
	return false

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition: _failures.append(label)
