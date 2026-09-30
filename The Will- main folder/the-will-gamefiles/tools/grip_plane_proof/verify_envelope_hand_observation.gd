extends "res://tools/grip_plane_proof/run_envelope_hand_match_proof.gd"

## Two frozen shared hand candidates, four digit planes observed three ways
## each. No pose search, production writes, or anatomy/skeleton replacement.
const FROZEN_TRACES: Dictionary = {
	"C:/WORKSPACE/test_artifacts/grip_placement_trace_hand_right_2026-09-18T02-30-57.bin": "dab0fbd68489e84ec1196c5a0acfb383a76a8eed099779e00a0f424c65529f89",
	"C:/WORKSPACE/test_artifacts/grip_placement_trace_hand_left_2026-09-18T02-31-08.bin": "c9765e43b465f5a529a07337bc2c9865d440612788960f162e7f40e5172311aa",
}
const RAW_FIELDS: Array[String] = ["known_excess_depth_lower_m", "exceeding_known_segment_count",
	"unresolved_known_segment_count", "unassigned_skin_depth_lower_m", "unassigned_skin_depth_upper_m",
	"unassigned_segment_count", "depth_evaluations"]
const ATTRACTION_FIELDS: Array[String] = ["target_error_upper_sum_m", "missing_required_contact_regions",
	"guide_points_m", "guide_points_origin_id"]

var _verification_checks: int = 0
var _verification_failures: Array[String] = []
var _verification_cases: Array[Dictionary] = []
var _verification_distinct_metrics: int = 0
var _verification_started: int = 0


func _run() -> void:
	_verification_started = Time.get_ticks_usec()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not _check(parsed is Dictionary and parsed.get("schema") == "contact_envelope_input_v1", "load explicit envelope configuration"):
		_finish_verification(); return
	for field: String in ["measured_radius_m", "envelope_radius_multiplier", "envelope_radius_m"]:
		if not _check(parsed.get(field) is float and is_finite(parsed[field]) and parsed[field] > 0.0, "valid envelope configuration " + field):
			_finish_verification(); return
	if not _check(absf(parsed.measured_radius_m * parsed.envelope_radius_multiplier - parsed.envelope_radius_m) <= 1.0e-12, "measured radius and multiplier reproduce configured radius"):
		_finish_verification(); return
	var measurement_path: String = str(parsed.get("measurement", "")).replace("\\", "/").simplify_path()
	if not _check(measurement_path.begins_with("C:/WORKSPACE/test_artifacts/") and measurement_path.get_extension() == "json" and not measurement_path.substr(3).contains(":"), "measurement reference remains inside workspace"):
		_finish_verification(); return
	if not _check(FileAccess.get_sha256(measurement_path) == parsed.get("measurement_sha256"), "measured anatomy reference hash matches"):
		_finish_verification(); return
	_envelope_config = parsed
	var loaded: Dictionary = Store.new().load_matching(OldInputs.DEFINITION_PATH, OldInputs.SIGNATURE, "rest_middle_thumb_surface_measurements_v1")
	if not _check(loaded.get("valid", false), "prepared anatomy loads without recalibration"):
		_finish_verification(); return
	var anatomy_before := var_to_bytes(loaded.resource.reference_skin)
	for path: String in FROZEN_TRACES:
		_test_trace(loaded.resource, path)
	_check(_verification_cases.size() == 4, "right and left Middle/Thumb initial observations completed")
	_check(_verification_distinct_metrics > 0, "actual wrapper changes contact metrics for at least one frozen digit")
	_check(var_to_bytes(loaded.resource.reference_skin) == anatomy_before, "original prepared anatomy remains unchanged")
	_finish_verification()


func _test_trace(definition: Resource, path: String) -> void:
	if not _check(_workspace_trace_path(path) and FileAccess.get_sha256(path) == FROZEN_TRACES[path], "frozen trace path and hash: " + path.get_file()):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not _check(file != null, "frozen trace is readable"):
		return
	var raw: Variant = file.get_var(false)
	file.close()
	if not _check(raw is Dictionary and raw.get("schema") == "grip_placement_trace_v1" and raw.get("valid", false) and raw.get("validation", {}).get("valid", false) and raw.get("capture_errors", []).is_empty() and raw.get("anatomy_signature") == definition.source_signature, "frozen trace is valid and matches anatomy"):
		return
	var trace: Dictionary = raw
	var chosen: Dictionary = {}
	for transaction: Dictionary in trace.transactions:
		if transaction.slot == trace.slot and transaction.get("result", {}).get("applied", false) and not transaction.get("finger_inputs", []).is_empty():
			chosen = transaction
	if not _check(not chosen.is_empty(), "frozen accepted seat supplies finger input"):
		return
	var stage: Dictionary = chosen.finger_inputs[-1]
	if not _check(stage.get("valid", false) and stage.get("stage") == &"finger_solve_input" and stage.get("transaction_serial") == chosen.serial and stage.posed_character.get("transaction_serial") == chosen.serial and stage.posed_character.get("capture_stage") == stage.stage and stage.posed_character.get("engine_process_frame") == stage.get("engine_process_frame"), "frozen input capture epoch remains coherent"):
		return
	var stage_before := var_to_bytes(stage)
	var context := _prepare(definition, stage)
	if not _check(context.get("valid", false), "envelope matching context prepares: " + str(context.get("reason", ""))):
		return
	var candidate: Dictionary = _builder.evaluate(context.adapter, {&"middle": [0.0,0.0,0.0], &"thumb": [0.0,0.0,0.0]}, Vector3.ZERO, ROOT)
	if not _check(candidate.get("valid", false), "single shared initial hand candidate prepares"):
		return
	var targets := _targets(context, candidate, [0.0,0.0])
	if not _check(targets.get("valid", false), "raw and actual wrapper target packets prepare"):
		return
	for digit: StringName in DIGITS:
		_test_observations(context, candidate, targets.digits[digit], digit)
	_check(var_to_bytes(stage) == stage_before, "frozen trace input remains unchanged")


func _test_observations(context: Dictionary, candidate: Dictionary, slice: Dictionary, digit: StringName) -> void:
	var label := "%s/%s" % [context.slot, digit]
	var before := var_to_bytes([context.observations[digit], candidate, slice.target, slice.contact_target])
	var raw: Dictionary = _observer.evaluate(context.observations[digit], candidate, slice.plane, slice.origin_id,
		slice.target, context.guide_initial_radius_m, true)
	var equal: Dictionary = _observer.evaluate(context.observations[digit], candidate, slice.plane, slice.origin_id,
		slice.target, context.guide_initial_radius_m, true, slice.target)
	var wrapped: Dictionary = _observer.evaluate(context.observations[digit], candidate, slice.plane, slice.origin_id,
		slice.target, context.guide_initial_radius_m, true, slice.contact_target)
	if not _check(raw.get("valid", false) and equal.get("valid", false) and wrapped.get("valid", false), label + ": all three observations succeed"):
		return
	for optional: Dictionary in [equal, wrapped]:
		for field: String in RAW_FIELDS:
			_check(optional[field] == raw[field], label + ": optional target preserves raw " + field)
		_check(var_to_bytes(optional.depth_measurements) == var_to_bytes(raw.depth_measurements), label + ": actual material depth packet is byte-identical")
		_check(var_to_bytes(optional.skin_segments) == var_to_bytes(raw.skin_segments), label + ": optional target observes byte-identical skin geometry")
		_check(optional.pose_id == raw.pose_id and optional.plane_origin_id == raw.plane_origin_id, label + ": optional target uses the same candidate and named plane")
		for index: int in raw.regions.size():
			var original: Dictionary = raw.regions[index]
			var region: Dictionary = optional.regions[index]
			for pair: Array in [["raw_material_nearest_gap_m", "nearest_gap_m"], ["raw_material_depth_lower_m", "depth_lower_m"], ["raw_material_depth_upper_m", "depth_upper_m"], ["raw_material_reachable_contact_witness_count", "reachable_contact_witness_count"], ["raw_material_section_cap_verified", "section_cap_verified"]]:
				_check(region[pair[0]] == original[pair[1]], label + ": raw region " + str(index + 1) + " " + pair[0] + " matches raw-only observation")
	for field: String in ATTRACTION_FIELDS:
		_check(var_to_bytes(equal[field]) == var_to_bytes(raw[field]), label + ": equal target preserves attraction " + field)
	for index: int in raw.regions.size():
		var trimmed: Dictionary = {}
		for field: String in raw.regions[index]:
			trimmed[field] = equal.regions[index][field]
		_check(var_to_bytes(trimmed) == var_to_bytes(raw.regions[index]), label + ": equal target reproduces complete original region " + str(index + 1))
	_check(var_to_bytes(equal.contact_depth_measurements) == var_to_bytes(raw.depth_measurements), label + ": equal contact polygon reproduces all raw query details")
	_check(wrapped.contact_depth_measurements.valid and wrapped.contact_depth_measurements.origin_id == slice.origin_id and wrapped.contact_depth_measurements.target_source_id == slice.contact_target.source_id, label + ": actual wrapper query retains its source and named origin")
	_check(wrapped.contact_target_source_id != wrapped.depth_measurements.target_source_id, label + ": wrapper and weapon source identities remain distinct")
	_check(wrapped.contact_target_polygon_m == slice.contact_target.polygon, label + ": output retains the full actual wrapper geometry")
	_check(wrapped.skin_slice_ms >= 0.0 and wrapped.depth_query_ms >= 0.0 and wrapped.contact_depth_query_ms >= 0.0, label + ": skin, material, and wrapper timings remain separate")
	if absf(float(wrapped.target_error_upper_sum_m) - float(raw.target_error_upper_sum_m)) > 1.0e-9:
		_verification_distinct_metrics += 1
	var wrong_origin: Dictionary = slice.contact_target.duplicate(true)
	wrong_origin.origin_id = &"WrongEnvelopeMeasurementPlane"
	var rejected: Dictionary = _observer.evaluate(context.observations[digit], candidate, slice.plane, slice.origin_id, slice.target, context.guide_initial_radius_m, false, wrong_origin)
	_check(not rejected.get("valid", false) and rejected.get("reason") == "missing_or_mismatched_contact_target_origin_or_source", label + ": wrong envelope origin rejected without fallback")
	var incomplete: Dictionary = slice.contact_target.duplicate(true)
	incomplete.complete = false
	rejected = _observer.evaluate(context.observations[digit], candidate, slice.plane, slice.origin_id, slice.target, context.guide_initial_radius_m, false, incomplete)
	_check(not rejected.get("valid", false) and rejected.get("reason") == "invalid_prepared_contact_target", label + ": incomplete envelope rejected without fallback")
	_check(before == var_to_bytes([context.observations[digit], candidate, slice.target, slice.contact_target]), label + ": observations and rejections leave inputs unchanged")
	_verification_cases.append({"slot": context.slot, "digit": digit, "pose_id": candidate.pose_packet.pose_id,
		"skin_segment_count": raw.skin_segments.size(), "raw_contact_error_m": raw.target_error_upper_sum_m,
		"wrapper_contact_error_m": wrapped.target_error_upper_sum_m, "raw_depth_query_ms": wrapped.depth_query_ms,
		"wrapper_depth_query_ms": wrapped.contact_depth_query_ms, "actual_3d_grip_verified": false})


func _check(condition: bool, label: String) -> bool:
	_verification_checks += 1
	if not condition:
		_verification_failures.append(label)
		push_error(label)
	return condition


func _finish_verification() -> void:
	var report := {"schema": "envelope_hand_observation_verifier_v1", "ok": _verification_failures.is_empty(),
		"checks": _verification_checks, "failures": _verification_failures, "cases": _verification_cases,
		"distinct_contact_metric_cases": _verification_distinct_metrics, "optimization_search_executed": false,
		"configuration_path": CONFIG_PATH, "configuration_sha256": FileAccess.get_sha256(CONFIG_PATH),
		"production_pose_written": false, "actual_3d_grip_verified": false, "grip_accepted": false,
		"elapsed_ms": float(Time.get_ticks_usec() - _verification_started) / 1000.0}
	var path := "C:/WORKSPACE/test_artifacts/verify_envelope_hand_observation_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot save envelope observation verification report"); quit(1); return
	file.store_string(JSON.stringify(_json(report), "\t")); file.close()
	print("ENVELOPE_HAND_OBSERVATION_RESULT=" + path)
	print("ENVELOPE_HAND_OBSERVATION_SUMMARY=" + JSON.stringify({"ok": report.ok, "checks": report.checks,
		"failures": report.failures, "cases": report.cases.size(), "elapsed_ms": report.elapsed_ms}))
	quit(0 if report.ok else 1)
