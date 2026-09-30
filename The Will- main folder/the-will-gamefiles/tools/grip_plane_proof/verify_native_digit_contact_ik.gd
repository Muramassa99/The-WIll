extends "res://tools/grip_plane_proof/run_circle_hand_process_proof.gd"

const Native = preload("res://tools/grip_plane_proof/native_digit_contact_ik.gd")
const FROZEN_TRACES: Dictionary = {
	"C:/WORKSPACE/test_artifacts/grip_placement_trace_hand_right_2026-09-18T02-30-57.bin": "dab0fbd68489e84ec1196c5a0acfb383a76a8eed099779e00a0f424c65529f89",
	"C:/WORKSPACE/test_artifacts/grip_placement_trace_hand_left_2026-09-18T02-31-08.bin": "c9765e43b465f5a529a07337bc2c9865d440612788960f162e7f40e5172311aa",
}
var _native := Native.new()
var _native_checks: int = 0
var _native_failures: Array[String] = []
var _native_cases: Array = []


func _run() -> void:
	var loaded: Dictionary = Store.new().load_matching(OldInputs.DEFINITION_PATH, OldInputs.SIGNATURE, "rest_middle_thumb_surface_measurements_v1")
	if not _check_native(loaded.get("valid", false), "load prepared anatomy"): _finish_native(); return
	var before := var_to_bytes(loaded.resource.reference_skin)
	for path: String in FROZEN_TRACES: await _test_native_trace(loaded.resource, path)
	_check_native(var_to_bytes(loaded.resource.reference_skin) == before, "original anatomy unchanged")
	_check_native(_native_cases.size() == 2, "both named hands exercised")
	_finish_native()


func _test_native_trace(definition: Resource, path: String) -> void:
	if not _check_native(_workspace_trace_path(path) and FileAccess.get_sha256(path) == FROZEN_TRACES[path], "workspace frozen trace hash"): return
	var file := FileAccess.open(path, FileAccess.READ)
	if not _check_native(file != null, "frozen trace readable"): return
	var raw: Variant = file.get_var(false); file.close()
	if not _check_native(raw is Dictionary and raw.get("valid", false) and raw.get("validation", {}).get("valid", false) and raw.get("capture_errors", []).is_empty() and raw.get("anatomy_signature") == definition.source_signature, "frozen trace valid"): return
	var chosen: Dictionary = {}
	for transaction: Dictionary in raw.transactions:
		if transaction.slot == raw.slot and transaction.get("result", {}).get("applied", false) and not transaction.get("finger_inputs", []).is_empty(): chosen = transaction
	if not _check_native(not chosen.is_empty(), "accepted source seat exists"): return
	var stage: Dictionary = chosen.finger_inputs[-1]
	var original := var_to_bytes(stage)
	var context: Dictionary = _prepare(definition, stage)
	if not _check_native(context.get("valid", false), "prepared source context"): return
	var parameters: Array = context.open_parameters.duplicate()
	for index: int in 6:
		var snapshot: Dictionary = context.adapter.digit_inputs[DIGITS[index / 3]].snapshot
		parameters[index] = (float(snapshot.min_angles_rad[index % 3]) + float(snapshot.max_angles_rad[index % 3])) * 0.5
	var shift: Vector3 = context.translation_u_world * 0.025 + context.translation_v_world * 0.015
	var candidate: Dictionary = _rigid_candidate(context, parameters, shift)
	if not _check_native(candidate.get("valid", false), "midrange translated candidate"): return
	var candidate_before := var_to_bytes(candidate)
	var contacts: Array = _measured_contacts(context, candidate)
	if not _check_native(contacts.size() == 5, "five actual skin witnesses"): return
	var prepared: Dictionary = _native.prepare(root, context)
	if not _check_native(prepared.get("valid", false), "isolated native skeleton preparation"): return
	var result: Dictionary = await _native.solve(prepared, candidate, contacts)
	_check_native(result.get("valid", false), str(context.slot) + ": native no-motion proxy round trip " + str(result))
	if result.get("valid", false):
		_check_native(result.native_process_count == 5, "each native contact chain processed and captured once")
		_check_native(result.solver_origin_id == Native.SOLVER_ORIGIN and result.solver_units_per_metre == 1000.0, "solver numerical units are explicitly named")
		var frames: Dictionary = {}
		for record: Dictionary in result.origin_records:
			var frame: Transform3D = record.transform_to_parent
			if record.parent_origin_id != &"": frame = (frames[record.parent_origin_id] as Transform3D) * frame
			frames[record.origin_id] = frame
		_check_native(frames.has(Native.SOLVER_ORIGIN) and absf((frames[Native.SOLVER_ORIGIN] as Transform3D).basis.x.length() - 0.001) < 0.000000001, "native origin conversion preserves one millimetre per solver unit")
		var last: Dictionary = result.native_calls[-1]
		var resolved: Vector3 = (result.machine_to_world as Transform3D) * (frames[last.proxy_origin_id] as Transform3D).origin
		_check_native(resolved.distance_to(last.solved_proxy_world) < Native.FRAME_TOLERANCE, "named native hierarchy resolves measured proxy to actual metric world")
		for digit: StringName in DIGITS:
			for joint: int in 3:
				_check_native(absf(result.angles[digit][joint] - candidate.digit_states[digit].angles_rad[joint]) < 0.0005, "same skin point target preserves calibrated angle")
	var contact: Dictionary = contacts[0].duplicate(true)
	var joint: Transform3D = candidate.digit_states[&"middle"].joint_transforms_world[0]
	var local: Vector3 = joint.affine_inverse() * (contact.skin_point_world as Vector3)
	var middle: Dictionary = context.adapter.digit_inputs[&"middle"].snapshot
	var direction: float = 0.02
	var moved: Transform3D = joint
	moved.basis = joint.basis * Basis((middle.hinge_axes_local[0] as Vector3).normalized(), direction)
	contact.target_point_world = moved * local
	var response: Dictionary = await _native.solve(prepared, candidate, [contact])
	_check_native(response.get("valid", false), str(context.slot) + ": native target movement returns valid hinges " + str(response))
	if response.get("valid", false):
		var initial_error: float = (contact.skin_point_world as Vector3).distance_to(contact.target_point_world)
		_check_native(response.native_calls[0].proxy_error_m < initial_error * 0.25, "native CCD responds to measured point target")
		_check_native(absf(response.angles[&"middle"][0] - candidate.digit_states[&"middle"].angles_rad[0]) > 0.001, "native joint angle actually changes")
		_check_native(response.off_axis_error_rad <= Native.OFF_AXIS_TOLERANCE and response.joint_limit_violations.is_empty(), "native response respects calibrated hinge and limits")
		var observed: Vector3 = response.native_calls[0].solved_proxy_world
		var plane: Transform3D = candidate.digit_states[&"middle"].plane_to_world
		_check_native(absf((observed - plane.origin).dot(plane.basis.z)) <= 0.00002, "native contact marker remains in digit motion plane")
	var locked_results: Array = []
	for measured: Dictionary in contacts:
		if measured.section == 1 or (measured.digit == &"thumb" and measured.section == 2): continue
		var locked: Dictionary = measured.duplicate(true)
		var fixed_count: int = int(locked.section) - 1
		locked["fixed_upstream_count"] = fixed_count
		var source_frame: Transform3D = candidate.digit_states[locked.digit].joint_transforms_world[fixed_count]
		var witness_local: Vector3 = source_frame.affine_inverse() * (locked.skin_point_world as Vector3)
		var input_snapshot: Dictionary = context.adapter.digit_inputs[locked.digit].snapshot
		var target_frame := Transform3D(source_frame.basis * Basis((input_snapshot.hinge_axes_local[fixed_count] as Vector3).normalized(), 0.02), source_frame.origin)
		locked.target_point_world = target_frame * witness_local
		var locked_response: Dictionary = await _native.solve(prepared, candidate, [locked])
		locked_results.append(locked_response)
		_check_native(locked_response.get("valid", false), str(context.slot) + ": feasible distal native target with fixed upstream " + str(locked.digit) + "/" + str(locked.section) + " " + str(locked_response))
		if locked_response.get("valid", false):
			for index: int in fixed_count:
				_check_native(absf(locked_response.angles[locked.digit][index] - candidate.digit_states[locked.digit].angles_rad[index]) <= Native.ANGLE_NUMERIC_TOLERANCE, "native temporary upstream lock survives solved pose")
			var initial_gap: float = (locked.skin_point_world as Vector3).distance_to(locked.target_point_world)
			_check_native(locked_response.native_calls[0].proxy_error_m < initial_gap * 0.25, "native distal hinge responds while proximal joints remain fixed")
			_check_native(absf(locked_response.angles[locked.digit][fixed_count] - candidate.digit_states[locked.digit].angles_rad[fixed_count]) > 0.001, "native unlocked distal angle actually changes")
			_check_native(locked_response.native_calls[0].temporary_joint_constraints.size() == fixed_count and locked_response.temporary_joint_lock_violations.is_empty(), "temporary constraints reported separately from anatomical ranges")
	var excess: Dictionary = contacts[0].duplicate(true)
	var beyond: float = float(middle.max_angles_rad[0]) - float(candidate.digit_states[&"middle"].angles_rad[0]) + 0.3
	moved = joint; moved.basis = joint.basis * Basis((middle.hinge_axes_local[0] as Vector3).normalized(), beyond)
	excess.target_point_world = moved * local
	var limited: Dictionary = await _native.solve(prepared, candidate, [excess])
	if limited.get("valid", false):
		_check_native(limited.angles[&"middle"][0] <= middle.max_angles_rad[0] and limited.angles[&"middle"][0] >= middle.min_angles_rad[0], "unreachable target never widens anatomical range")
	else:
		_check_native(limited.get("reason") == "native_joint_limit_or_axis_violation", "invalid native bound result explicitly rejected")
	var invalid_contact: Dictionary = contacts[0].duplicate(true); invalid_contact.target_origin_id = &"Anonymous"
	var rejected: Dictionary = await _native.solve(prepared, candidate, [invalid_contact])
	_check_native(not rejected.get("valid", false) and rejected.get("reason") == "missing_native_contact_origin_or_source", "unnamed target chain rejected before native processing")
	invalid_contact = contacts[0].duplicate(true); invalid_contact["fixed_upstream_count"] = -1
	rejected = await _native.solve(prepared, candidate, [invalid_contact])
	_check_native(not rejected.get("valid", false) and rejected.get("reason") == "invalid_native_fixed_upstream_count", "invalid temporary lock count rejected before native processing")
	_check_native(var_to_bytes(candidate) == candidate_before and var_to_bytes(stage) == original, "native experiment does not mutate source candidate or capture")
	_native_cases.append({"slot": context.slot, "round_trip": result, "movement": response, "limit_probe": limited, "fixed_upstream_probes": locked_results,
		"native_total_process_count": prepared.native_process_count, "production_pose_written": false})
	_native.dispose(prepared)


func _measured_contacts(context: Dictionary, candidate: Dictionary) -> Array:
	var contacts: Array = []
	for digit: StringName in DIGITS:
		var state: Dictionary = candidate.digit_states[digit]
		var input: Dictionary = context.observations[digit].duplicate()
		input.machine_to_world = candidate.pose_packet.machine_to_world
		var sliced: Dictionary = _observer.slice_candidate(input, candidate, state.plane_to_world, state.plane_origin_id)
		if not sliced.get("valid", false): return []
		for section: int in [1, 2, 3]:
			if digit == &"thumb" and section == 1: continue
			var chosen: Dictionary = {}
			var length: float = -1.0
			for index: int in sliced.owned[section - 1]:
				var segment: Dictionary = sliced.segments[index]
				var measure: float = (segment.a as Vector2).distance_squared_to(segment.b)
				if measure > length: chosen = segment; length = measure
			if chosen.is_empty(): return []
			var point: Vector2 = (chosen.a as Vector2).lerp(chosen.b, 0.5)
			var world: Vector3 = state.plane_to_world * Vector3(point.x, point.y, 0.0)
			contacts.append({"digit": digit, "section": section, "source_id": chosen.source_id,
				"skin_point_world": world, "target_point_world": world, "skin_origin_id": ROOT, "target_origin_id": ROOT})
	return contacts


func _check_native(condition: bool, label: String) -> bool:
	_native_checks += 1
	if not condition: _native_failures.append(label); push_error(label)
	return condition


func _finish_native() -> void:
	var report := {"schema": "native_digit_contact_ik_verifier_v1", "ok": _native_failures.is_empty(),
		"checks": _native_checks, "failures": _native_failures, "cases": _native_cases,
		"actual_skin_validation_required": true, "grip_accepted": false, "production_pose_written": false}
	var path := "C:/WORKSPACE/test_artifacts/verify_native_digit_contact_ik_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: push_error("Cannot save native verifier"); quit(1); return
	file.store_string(JSON.stringify(_json(report), "\t")); file.close()
	print("NATIVE_DIGIT_CONTACT_IK_RESULT=" + path)
	print("NATIVE_DIGIT_CONTACT_IK_SUMMARY=" + JSON.stringify({"ok": report.ok, "checks": report.checks, "failures": report.failures}))
	quit(0 if report.ok else 1)
