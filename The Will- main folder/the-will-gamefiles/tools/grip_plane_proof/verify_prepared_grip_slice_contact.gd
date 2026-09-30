extends "res://tools/grip_plane_proof/run_coordinated_grip_closure_proof.gd"

const SliceObserver = preload("res://tools/grip_plane_proof/prepared_grip_slice_contact.gd")
const FROZEN_REPORT: String = "C:/WORKSPACE/test_artifacts/coordinated_grip_closure_2026-09-18T04-33-42.json"
const FROZEN_REPORT_SHA256: String = "b16ec0089f12ea2da5361f409a28cfc907243e4725468d1e40dd7d804158e440"
const NONFINITE_MARKER: String = "__grip_observer_explicit_nonfinite_float__"
const FROZEN_TRACES: Dictionary = {
	"C:/WORKSPACE/test_artifacts/grip_placement_trace_hand_right_2026-09-18T02-30-57.bin": "dab0fbd68489e84ec1196c5a0acfb383a76a8eed099779e00a0f424c65529f89",
	"C:/WORKSPACE/test_artifacts/grip_placement_trace_hand_left_2026-09-18T02-31-08.bin": "c9765e43b465f5a529a07337bc2c9865d440612788960f162e7f40e5172311aa",
}
const OBSERVATION_FIELDS: Array[String] = [
	"regions", "target_error_upper_sum_m", "known_excess_depth_lower_m",
	"unassigned_skin_depth_lower_m", "unassigned_segment_count", "unassigned_skin_depth_upper_m",
	"missing_required_contact_regions", "unresolved_known_segment_count", "exceeding_known_segment_count",
	"guide_points_m", "guide_points_origin_id", "reach_center_m", "reach_m", "all_contributors_preserved",
	"grip_accepted", "angles_rad", "translation_world", "translation_world_origin_id", "affected_vertex_count",
]

var _observer_checks: int = 0
var _observer_failures: Array[String] = []
var _observer_cases: Array[Dictionary] = []
var _observer_evaluations: int = 0
var _observer_started: int = 0


## The inherited _init defers this override. The legacy runner is the independent
## comparison path: its _trial still has its own pre-extraction measurement code.
func _run() -> void:
	_observer_started = Time.get_ticks_usec()
	var loaded: Dictionary = Store.new().load_matching(Runner.DEFINITION_PATH, Runner.SIGNATURE, "rest_middle_thumb_surface_measurements_v1")
	if not _observer_check(bool(loaded.get("valid", false)), "load existing prepared anatomy"):
		_finish_observer_report()
		return
	if not _observer_check(FileAccess.get_sha256(FROZEN_REPORT) == FROZEN_REPORT_SHA256, "frozen report content hash remains unchanged"):
		_finish_observer_report()
		return
	var source: Variant = _parse_frozen_numbers(FileAccess.get_file_as_string(FROZEN_REPORT))
	if not _observer_check(source is Dictionary and source.get("schema") == "coordinated_grip_closure_proof_v1" and bool(source.get("ok", false)), "read valid frozen final closure report"):
		_finish_observer_report()
		return
	var anatomy_before: PackedByteArray = var_to_bytes(loaded.resource.reference_skin)
	_test_nonfinite_comparisons()
	var seen: Dictionary = {}
	for case: Dictionary in source.cases:
		if case.get("kind") != "actual":
			continue
		var label: String = "%s/%s" % [case.get("slot"), case.get("digit")]
		if not _observer_check(not seen.has(label), label + " appears only once in frozen report"):
			continue
		seen[label] = true
		_test_observer_case(loaded.resource, case)
	for slot: String in ["hand_right", "hand_left"]:
		for digit: String in ["middle", "thumb"]:
			_observer_check(seen.has(slot + "/" + digit), "frozen report covers " + slot + "/" + digit)
	_observer_check(_observer_evaluations == 8, "exactly eight initial/selected observation comparisons completed")
	_observer_check(var_to_bytes(loaded.resource.reference_skin) == anatomy_before, "all comparisons preserve original saved skin arrays")
	_finish_observer_report()


func _test_observer_case(definition: Resource, case: Dictionary) -> void:
	var label: String = "%s/%s" % [case.slot, case.digit]
	var path: String = case.get("source_trace", "")
	if not _observer_check(FROZEN_TRACES.has(path) and _workspace_trace_path(path), label + " uses an explicit permitted frozen trace"):
		return
	var digest: String = FileAccess.get_sha256(path)
	if not _observer_check(digest == FROZEN_TRACES[path] and digest == case.get("source_trace_sha256"), label + " frozen trace hash matches"):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not _observer_check(file != null, label + " frozen trace readable"):
		return
	var raw: Variant = file.get_var(false)
	file.close()
	if not _observer_check(raw is Dictionary and raw.get("schema") == "grip_placement_trace_v1" and bool(raw.get("valid", false)) and bool(raw.get("validation", {}).get("valid", false)) and raw.get("capture_errors", []).is_empty(), label + " frozen trace validated"):
		return
	var trace: Dictionary = raw
	if not _observer_check(trace.slot == StringName(case.slot) and trace.anatomy_signature == definition.source_signature, label + " trace slot and anatomy match"):
		return
	var chosen: Dictionary = {}
	for transaction: Dictionary in trace.transactions:
		if transaction.slot == trace.slot and transaction.get("result", {}).get("applied", false) and not transaction.get("finger_inputs", []).is_empty():
			chosen = transaction
	if not _observer_check(not chosen.is_empty(), label + " accepted seat supplies frozen coherent finger input"):
		return
	var stage: Dictionary = chosen.finger_inputs[chosen.finger_inputs.size() - 1]
	var stage_before: PackedByteArray = var_to_bytes(stage)
	var digit_id: StringName = StringName(case.digit)
	var context: Dictionary = _prepare_trial(definition, chosen, stage, digit_id)
	if not _observer_check(bool(context.get("valid", false)), label + " old context prepares: " + str(context.get("reason", ""))):
		return
	var observer: RefCounted = SliceObserver.new()
	var prepared: Dictionary = observer.prepare(context.adapter, digit_id)
	if not _observer_check(bool(prepared.get("valid", false)), label + " observer prepares: " + str(prepared.get("reason", ""))):
		return
	_observer_compare(prepared.selected_weights, context.groups.weights, label + " original-order selected weights", 0.0)
	_observer_compare(prepared.triangle_ids, context.region.triangle_ids, label + " source triangle region", 0.0)
	_observer_compare(prepared.metadata, context.region.metadata, label + " full-weight ownership metadata", 0.0)
	_observer_compare(prepared.targets_m, context.region.targets_m, label + " recovered section targets", 0.0)
	_observer_compare(prepared.caps_m, context.region.caps_m, label + " recovered section caps", 0.0)
	_observer_compare(prepared.section_ownership, context.region.section_ownership, label + " ownership policy", 0.0)
	_observer_compare(prepared.safety_cap_policy, context.region.safety_cap_policy, label + " provisional cap policy", 0.0)
	var target: Dictionary = _depth_query.prepare_target(context.actual_polygon, context.plane_origin_id, &"ClosureTrial_actual", true)
	if not _observer_check(bool(target.get("valid", false)), label + " complete actual target prepares"):
		return
	var prepared_before: PackedByteArray = var_to_bytes(prepared)
	var adapter_before: PackedByteArray = var_to_bytes(context.adapter)
	for pose_name: String in ["initial", "selected"]:
		var pose_label: String = label + "/" + pose_name
		var saved: Dictionary = case[pose_name]
		var parameters: Array = saved.parameters.duplicate()
		if not _observer_check(parameters.size() == 4, pose_label + " recorded four search parameters"):
			continue
		var angles: Array[float] = [float(parameters[0]), float(parameters[1]), float(parameters[2])]
		var translation: Vector3 = context.slide_direction_world * float(parameters[3])
		var candidate: Dictionary = _candidate_adapter.evaluate(context.adapter, {digit_id: angles}, translation, &"RL_BoneRoot")
		if not _observer_check(bool(candidate.get("valid", false)), pose_label + " coherent candidate generated"):
			continue
		# The baseline used an explicitly registered frozen frame. Register that
		# same frame in this local candidate packet; no current anatomy substitutes.
		candidate.pose_packet.origin_records.append(context.plane_origin_record.duplicate(true))
		var before: PackedByteArray = var_to_bytes([prepared, candidate, target])
		var actual: Dictionary = observer.evaluate(prepared, candidate, context.plane, context.plane_origin_id, target, context.guide_initial_radius_m, true)
		var legacy: Dictionary = _trial(context, target, parameters, true)
		if not _observer_check(bool(actual.get("valid", false)) and bool(legacy.get("valid", false)), pose_label + " both measurement paths succeed: " + str(actual.get("reason", ""))):
			continue
		_observer_evaluations += 1
		_observer_compare(_observation_only(actual), _observation_only(legacy), pose_label + " exact live measurement summaries", 0.0)
		_observer_compare(actual.skin_segments, legacy.skin_segments, pose_label + " exact source skin segments", 0.0)
		_observer_compare(actual.depth_measurements, legacy.depth_measurements, pose_label + " exact live depth records", 0.0)
		# Recorded decimal JSON is an independent checkpoint, not the live oracle.
		# Tight numeric tolerance permits serialization's decimal round trip only.
		_observer_compare(_observation_only(legacy), _observation_only(saved), pose_label + " frozen report measurement checkpoint", 0.00000001)
		_observer_compare(legacy.skin_segments, saved.skin_segments, pose_label + " frozen report skin checkpoint", 0.00000001)
		_observer_compare(legacy.depth_measurements, saved.depth_measurements, pose_label + " frozen report depth checkpoint", 0.00000001)
		_observer_check(var_to_bytes([prepared, candidate, target]) == before, pose_label + " observer and legacy comparison preserve inputs")
		if pose_name == "initial":
			_test_observer_rejections(observer, prepared, candidate, context, target, pose_label)
		_observer_cases.append({"slot": case.slot, "digit": digit_id, "pose": pose_name,
			"skin_segments": actual.skin_segments.size(), "depth_evaluations": actual.depth_evaluations,
			"observation_ms": actual.observation_ms, "plane_origin_validation_ms": actual.plane_origin_validation_ms,
			"legacy_trial_ms": legacy.trial_ms, "grip_accepted": false})
	_observer_check(var_to_bytes(prepared) == prepared_before, label + " observer preparation remains immutable")
	_observer_check(var_to_bytes(context.adapter) == adapter_before, label + " candidate preparation remains immutable")
	_observer_check(var_to_bytes(stage) == stage_before, label + " frozen trace stage remains immutable")


func _test_observer_rejections(observer: RefCounted, prepared: Dictionary, candidate: Dictionary, context: Dictionary, target: Dictionary, label: String) -> void:
	var before: PackedByteArray = var_to_bytes([prepared, candidate, target])
	var without_plane: Dictionary = candidate.duplicate(true)
	var records: Array = without_plane.pose_packet.origin_records
	for index: int in range(records.size() - 1, -1, -1):
		if records[index].origin_id == context.plane_origin_id:
			records.remove_at(index)
	var missing: Dictionary = observer.evaluate(prepared, without_plane, context.plane, context.plane_origin_id, target, context.guide_initial_radius_m)
	_observer_reject(missing, "missing_registered_measurement_plane", label + " reject unregistered plane")
	var unnamed: Dictionary = observer.evaluate(prepared, candidate, context.plane, StringName(), target, context.guide_initial_radius_m)
	_observer_reject(unnamed, "missing_or_mismatched_plane_origin", label + " reject empty plane name")
	var moved_plane: Transform3D = context.plane
	moved_plane.origin += moved_plane.basis.x * 0.001
	var mismatch: Dictionary = observer.evaluate(prepared, candidate, moved_plane, context.plane_origin_id, target, context.guide_initial_radius_m)
	_observer_reject(mismatch, "measurement_plane_does_not_match_registered_frame", label + " reject mismatched plane frame")
	var wrong_target: Dictionary = target.duplicate(true)
	wrong_target.origin_id = &"WrongTargetPlane"
	var target_result: Dictionary = observer.evaluate(prepared, candidate, context.plane, context.plane_origin_id, wrong_target, context.guide_initial_radius_m)
	_observer_reject(target_result, "missing_or_mismatched_plane_origin", label + " reject target origin mismatch")
	var wrong_signature: Dictionary = candidate.duplicate(true)
	wrong_signature.pose_packet.anatomy_signature = "different_anatomy"
	var signature_result: Dictionary = observer.evaluate(prepared, wrong_signature, context.plane, context.plane_origin_id, target, context.guide_initial_radius_m)
	_observer_reject(signature_result, "candidate_source_or_anatomy_mismatch", label + " reject mismatched anatomy signature")
	_observer_check(var_to_bytes([prepared, candidate, target]) == before, label + " rejection checks preserve original inputs")


func _observation_only(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in OBSERVATION_FIELDS:
		result[key] = value.get(key)
	return result


func _observer_compare(actual: Variant, expected: Variant, label: String, tolerance: float) -> void:
	# Convert engine vectors/frames directly; do not serialize INF to 1e99999
	# and reparse it. Infinity stays an explicit numeric value, not zero/missing.
	var left: Variant = _numbers(actual)
	var right: Variant = _numbers(expected)
	var difference: String = _observer_difference(left, right, "$", tolerance)
	_observer_check(difference.is_empty(), label + ("; " + difference if not difference.is_empty() else ""))


func _parse_frozen_numbers(text: String) -> Variant:
	# The pinned historical Godot JSON writes infinity as an overflowing numeric
	# token. Replace only complete numeric tokens outside quoted strings, parse
	# once without overflow warnings, then restore signed floating-point infinity.
	var rewritten: String = ""
	var copied_until: int = 0
	var index: int = 0
	var in_string: bool = false
	var escaped: bool = false
	while index < text.length():
		var character: String = text.substr(index, 1)
		if in_string:
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == "\"":
				in_string = false
		elif character == "\"":
			in_string = true
		elif character == "1" or character == "-":
			var token: String = "-1e99999" if character == "-" else "1e99999"
			var previous: String = text.substr(index - 1, 1) if index > 0 else ""
			var following: String = text.substr(index + token.length(), 1) if index + token.length() < text.length() else ""
			if text.substr(index, token.length()) == token and (previous.is_empty() or " \t\r\n[:,".contains(previous)) and (following.is_empty() or " \t\r\n]},".contains(following)):
				rewritten += text.substr(copied_until, index - copied_until)
				rewritten += '{"' + NONFINITE_MARKER + '":"' + ("negative_infinity" if character == "-" else "positive_infinity") + '"}'
				index += token.length()
				copied_until = index
				continue
		index += 1
	rewritten += text.substr(copied_until)
	return _restore_frozen_nonfinite(JSON.parse_string(rewritten))


func _restore_frozen_nonfinite(value: Variant) -> Variant:
	if value is Dictionary:
		if value.size() == 1 and value.has(NONFINITE_MARKER):
			if value[NONFINITE_MARKER] == "positive_infinity":
				return INF
			if value[NONFINITE_MARKER] == "negative_infinity":
				return -INF
		var restored: Dictionary = {}
		for key: Variant in value:
			restored[key] = _restore_frozen_nonfinite(value[key])
		return restored
	if value is Array:
		var restored: Array = []
		for item: Variant in value:
			restored.append(_restore_frozen_nonfinite(item))
		return restored
	return value


func _test_nonfinite_comparisons() -> void:
	var restored: Variant = _parse_frozen_numbers('{"positive":1e99999,"negative":-1e99999,"literal":"1e99999","escaped":"a\\\"1e99999","zero":0,"missing":null}')
	_observer_check(restored is Dictionary and restored.positive == INF and restored.negative == -INF, "historical numeric tokens restore signed infinities")
	_observer_check(restored is Dictionary and restored.literal == "1e99999" and restored.escaped == 'a"1e99999', "historical infinity-token reader preserves quoted strings and escapes")
	_observer_check(_observer_difference(INF, INF, "$", 0.0).is_empty(), "equal positive infinity compares explicitly")
	_observer_check(_observer_difference(INF, -INF, "$", 0.0) != "", "opposite infinity signs differ")
	_observer_check(_observer_difference(INF, null, "$", 0.0) != "" and _observer_difference(INF, 0.0, "$", 0.0) != "", "infinity is neither missing nor zero")
	_observer_check(_observer_difference(null, 0.0, "$", 0.0) != "", "missing value remains distinct from zero")


func _observer_difference(left: Variant, right: Variant, path: String, tolerance: float) -> String:
	if (left is int or left is float) and (right is int or right is float):
		if left == right:
			return ""
		if is_finite(float(left)) and is_finite(float(right)) and absf(float(left) - float(right)) <= tolerance:
			return ""
		return "%s: %s != %s" % [path, str(left), str(right)]
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size():
			return path + ": dictionary field count differs"
		for key: Variant in left:
			if not right.has(key):
				return path + ": missing " + str(key)
			var difference: String = _observer_difference(left[key], right[key], path + "." + str(key), tolerance)
			if not difference.is_empty():
				return difference
		return ""
	if left is Array and right is Array:
		if left.size() != right.size():
			return path + ": array size differs"
		for index: int in range(left.size()):
			var difference: String = _observer_difference(left[index], right[index], "%s[%d]" % [path, index], tolerance)
			if not difference.is_empty():
				return difference
		return ""
	return "" if left == right else "%s: %s != %s" % [path, str(left), str(right)]


func _observer_reject(result: Dictionary, reason: String, label: String) -> void:
	_observer_check(not bool(result.get("valid", false)) and result.get("reason") == reason, label + ": " + str(result.get("reason")))


func _observer_check(condition: bool, label: String) -> bool:
	_observer_checks += 1
	if not condition:
		_observer_failures.append(label)
		push_error(label)
	return condition


func _finish_observer_report() -> void:
	var report: Dictionary = {"schema": "prepared_grip_slice_contact_verifier_v1", "ok": _observer_failures.is_empty(),
		"checks": _observer_checks, "failures": _observer_failures, "cases": _observer_cases,
		"comparison_count": _observer_evaluations, "frozen_report": FROZEN_REPORT,
		"frozen_report_sha256": FileAccess.get_sha256(FROZEN_REPORT),
		"oracle": "unchanged_legacy_trial_measurement_against_same_coherent_candidate_and_frozen_plane",
		"live_comparison_tolerance": 0.0, "frozen_json_checkpoint_tolerance": 0.00000001,
		"anatomy_recomputed": false, "production_pose_written": false,
		"actual_3d_grip_verified": false, "grip_accepted": false,
		"elapsed_ms": float(Time.get_ticks_usec() - _observer_started) / 1000.0}
	var path: String = "C:/WORKSPACE/test_artifacts/verify_prepared_grip_slice_contact_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write slice observer verifier report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("GRIP_SLICE_CONTACT_RESULT=" + path)
	print("GRIP_SLICE_CONTACT_SUMMARY=" + JSON.stringify(report))
	quit(0 if _observer_failures.is_empty() else 1)
