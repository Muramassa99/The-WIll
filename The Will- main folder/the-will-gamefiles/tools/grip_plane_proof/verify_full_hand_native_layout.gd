extends "res://tools/grip_plane_proof/run_handle_grip_process_proof.gd"

const FROZEN_TRACES: Dictionary = {
	"C:/WORKSPACE/test_artifacts/full_hand_placement_hand_right_2026-09-27T08-27-39.bin": "dbac84473adda892ba03654c2bfe158c143eede1c7b8a4816761e6f129e33f0d",
	"C:/WORKSPACE/test_artifacts/full_hand_placement_hand_left_2026-09-27T08-27-39.bin": "f1a7e2aa22c4e96fb6f3285a46a05d9f6d0767b49342c1538a8f16a68c4f7f4c",
}
var _native_checks: int = 0
var _native_failures: Array[String] = []
var _native_cases: Array = []


func _run() -> void:
	var loaded: Dictionary = Store.new().load_matching(FULL_PATH, FULL_SIGNATURE, "rest_all_digits_surface_measurements_v1")
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
	_test_layout(context)
	var parameters: Array = context.open_parameters.duplicate()
	for index: int in _angle_count():
		var snapshot: Dictionary = context.adapter.digit_inputs[_selected_digits()[index / 3]].snapshot
		parameters[index] = (float(snapshot.min_angles_rad[index % 3]) + float(snapshot.max_angles_rad[index % 3])) * 0.5
	var shift: Vector3 = context.translation_u_world * 0.025 + context.translation_v_world * 0.015
	var candidate: Dictionary = _rigid_candidate(context, parameters, shift)
	if not _check_native(candidate.get("valid", false), "midrange translated candidate"): return
	var candidate_before := var_to_bytes(candidate)
	var contacts: Array = _measured_contacts(context, candidate)
	if not _check_native(contacts.size() == 14, "fourteen actual skin witnesses"): return
	var prepared: Dictionary = _native.prepare(root, context)
	if not _check_native(prepared.get("valid", false), "isolated native skeleton preparation"): return
	_check_full_native_preparation(context, prepared)
	var result: Dictionary = await _native.solve(prepared, candidate, contacts)
	_check_native(result.get("valid", false), str(context.slot) + ": native no-motion proxy round trip " + str(result))
	if result.get("valid", false):
		_check_native(result.native_process_count == 14, "each native contact chain processed and captured once")
		_check_native(result.solver_origin_id == NativeContact.SOLVER_ORIGIN and result.solver_units_per_metre == 1000.0, "solver numerical units are explicitly named")
		var frames: Dictionary = {}
		for record: Dictionary in result.origin_records:
			var frame: Transform3D = record.transform_to_parent
			if record.parent_origin_id != &"": frame = (frames[record.parent_origin_id] as Transform3D) * frame
			frames[record.origin_id] = frame
		_check_native(frames.has(NativeContact.SOLVER_ORIGIN) and absf((frames[NativeContact.SOLVER_ORIGIN] as Transform3D).basis.x.length() - 0.001) < 0.000000001, "native origin conversion preserves one millimetre per solver unit")
		var last: Dictionary = result.native_calls[-1]
		var resolved: Vector3 = (result.machine_to_world as Transform3D) * (frames[last.proxy_origin_id] as Transform3D).origin
		_check_native(resolved.distance_to(last.solved_proxy_world) < NativeContact.FRAME_TOLERANCE, "named native hierarchy resolves measured proxy to actual metric world")
		for digit: StringName in _selected_digits():
			for joint: int in 3:
				_check_native(absf(result.angles[digit][joint] - candidate.digit_states[digit].angles_rad[joint]) < 0.0005, "same skin point target preserves calibrated angle")
	var extra_movement: Array = await _extra_digit_motion(context, prepared, candidate, contacts)
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
		_check_native(response.off_axis_error_rad <= NativeContact.OFF_AXIS_TOLERANCE and response.joint_limit_violations.is_empty(), "native response respects calibrated hinge and limits")
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
				_check_native(absf(locked_response.angles[locked.digit][index] - candidate.digit_states[locked.digit].angles_rad[index]) <= NativeContact.ANGLE_NUMERIC_TOLERANCE, "native temporary upstream lock survives solved pose")
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
	_native_cases.append({"slot": context.slot, "round_trip": result, "movement": response, "additional_digit_movement": extra_movement, "limit_probe": limited, "fixed_upstream_probes": locked_results,
		"native_total_process_count": prepared.native_process_count, "production_pose_written": false})
	_native.dispose(prepared)


func _measured_contacts(context: Dictionary, candidate: Dictionary) -> Array:
	var contacts: Array = []
	for digit: StringName in _selected_digits():
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
	var report := {"schema": "full_hand_native_layout_verifier_v1", "ok": _native_failures.is_empty(),
		"selected_digits": _selected_digits(), "source_sha256": _source_hashes(), "checks": _native_checks, "failures": _native_failures, "cases": _native_cases,
		"actual_skin_validation_required": true, "grip_accepted": false, "production_pose_written": false}
	var path := "C:/WORKSPACE/test_artifacts/verify_full_hand_native_layout_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: push_error("Cannot save native verifier"); quit(1); return
	file.store_string(JSON.stringify(_json(report), "\t")); file.close()
	print("FULL_HAND_NATIVE_LAYOUT_RESULT=" + path)
	print("FULL_HAND_NATIVE_LAYOUT_SUMMARY=" + JSON.stringify({"ok": report.ok, "checks": report.checks, "failures": report.failures}))
	quit(0 if report.ok else 1)

## Bounded native/layout regression only. No guide search or live pose write.
const FULL_SIGNATURE := "4935fa57cf6cc689121ae6077987b0985fc1fa7d0d3d8718f096418ea3c5b702"
const FULL_PATH := "res://tools/grip_plane_proof/prepared_characters/josie/" + FULL_SIGNATURE + ".tres"
const FULL_DIGITS: Array[StringName] = [&"middle", &"thumb", &"index", &"ring", &"pinky"]
var _legacy_layout: bool = false

func _selected_digits() -> Array[StringName]:
	if _legacy_layout:
		return DIGITS
	return FULL_DIGITS

func _source_hashes() -> Dictionary:
	var out: Dictionary = {"anatomy":FileAccess.get_sha256(FULL_PATH), "traces":FROZEN_TRACES}
	for filename: String in ["verify_full_hand_native_layout.gd","native_digit_contact_ik.gd","run_shared_hand_closure_proof.gd","run_circle_hand_process_proof.gd","run_tangent_hand_process_proof.gd","run_native_envelope_follow_proof.gd","run_handle_grip_process_proof.gd"]:
		out[filename] = FileAccess.get_sha256("res://tools/grip_plane_proof/" + filename)
	return out

func _check_full_native_preparation(context: Dictionary, prepared: Dictionary) -> void:
	_check_native(prepared.digits == _selected_digits() and prepared.indices.size() == 5 and prepared.proxies.size() == 14, "native skeleton has all five selected chains and fourteen proxies")
	var skeleton: Skeleton3D = prepared.skeleton
	for digit: StringName in _selected_digits():
		var snapshot: Dictionary = context.adapter.digit_inputs[digit].snapshot
		var parent: int = prepared.hand_index
		for joint: int in 3:
			var index: int = prepared.indices[digit][joint]
			_check_native(skeleton.get_bone_parent(index) == parent, "native chain remains under selected Hand: " + str(digit) + "/" + str(joint))
			var expected: StringName = context.adapter.hand_bone_name if joint == 0 else snapshot.bone_names[joint-1]
			_check_native(snapshot.relative_transform_origin_ids[joint] == expected, "native source parent matches selected Hand chain")
			parent = index
		_check_native(var_to_bytes(prepared.inputs[digit].snapshot) == var_to_bytes(snapshot), "native preparation preserves source axes and anatomical limits")
	var wrong: Dictionary = context.duplicate(true)
	wrong.adapter.digit_inputs[&"index"].snapshot.relative_transform_origin_ids[0] = &"CC_Base_L_Hand" if context.slot == &"hand_right" else &"CC_Base_R_Hand"
	var rejected: Dictionary = _native.prepare(root, wrong)
	_check_native(not rejected.get("valid",false) and rejected.get("reason") == "native_digit_parent_chain_does_not_match_selected_hand", "mixed-hand parent cannot be silently reparented")
	if rejected.get("valid",false): _native.dispose(rejected)

func _extra_digit_motion(context: Dictionary, prepared: Dictionary, candidate: Dictionary, contacts: Array) -> Array:
	var out: Array = []
	for digit: StringName in [&"thumb", &"index", &"ring", &"pinky"]:
		var contact: Dictionary = {}
		for measured: Dictionary in contacts:
			if measured.digit == digit: contact = measured.duplicate(true); break
		if not _check_native(not contact.is_empty(), "moving target witness exists: " + str(digit)): continue
		var joint_index: int = int(contact.section)-1
		var snapshot: Dictionary = context.adapter.digit_inputs[digit].snapshot
		var frame: Transform3D = candidate.digit_states[digit].joint_transforms_world[joint_index]
		var local: Vector3 = frame.affine_inverse() * (contact.skin_point_world as Vector3)
		var target_frame := Transform3D(frame.basis * Basis((snapshot.hinge_axes_local[joint_index] as Vector3).normalized(),0.02),frame.origin)
		contact.target_point_world = target_frame * local
		contact["fixed_upstream_count"] = joint_index
		var before: PackedByteArray = var_to_bytes(prepared.inputs)
		var response: Dictionary = await _native.solve(prepared,candidate,[contact])
		_check_native(response.get("valid",false), "actual native moving-target solve: " + str(digit) + " " + str(response.get("reason","")))
		if response.get("valid",false):
			var initial_gap: float = (contact.skin_point_world as Vector3).distance_to(contact.target_point_world)
			_check_native(response.native_calls[0].proxy_error_m < initial_gap*0.25, "native response reduces point error: " + str(digit))
			_check_native(absf(response.angles[digit][joint_index]-candidate.digit_states[digit].angles_rad[joint_index]) > 0.001, "selected native hinge moves: " + str(digit))
			_check_native(response.off_axis_error_rad <= NativeContact.OFF_AXIS_TOLERANCE and response.joint_limit_violations.is_empty() and response.temporary_joint_lock_violations.is_empty(), "all-five native result preserves axes, ranges and locks")
			for other: StringName in _selected_digits():
				if other == digit: continue
				for joint: int in 3:
					_check_native(absf(response.angles[other][joint]-candidate.digit_states[other].angles_rad[joint]) < 0.0005, "moving one chain preserves other selected chains")
		_check_native(var_to_bytes(prepared.inputs) == before, "native solve does not alter anatomical limits")
		out.append({"digit":digit,"result":response})
	return out

func _test_layout(context: Dictionary) -> void:
	# The fitting helper requires this context field even with no radius variables.
	context = context.duplicate()
	context["start_radius_m"] = 0.05
	_check_native(_parameter_count() == 17 and _angle_count() == 15 and _translation_u_index() == 15 and _translation_v_index() == 16, "full-hand layout has fifteen angles and two offsets")
	var markers: Array = []
	for index: int in 17: markers.append(float(index))
	var mapped: Dictionary = _angles_by_digit(markers)
	for index: int in 5:
		_check_native(mapped[_selected_digits()[index]] == markers.slice(index*3,index*3+3), "full-hand angle mapping preserves ordered coordinates")
	_legacy_layout = true
	_check_native(_parameter_count() == 8 and _translation_u_index() == 6 and _translation_v_index() == 7, "default two-digit layout unchanged")
	for trial: int in 3:
		var parameters: Array = []
		for index: int in 6:
			var snapshot: Dictionary = context.adapter.digit_inputs[DIGITS[index/3]].snapshot
			parameters.append(snapshot.min_angles_rad[index%3] if trial == 0 else (snapshot.max_angles_rad[index%3] if trial == 1 else (snapshot.min_angles_rad[index%3]+snapshot.max_angles_rad[index%3])*0.5))
		parameters.append(0.01); parameters.append(-0.02)
		var matrix: Array = []; var rhs: PackedFloat64Array = []
		for row: int in 8:
			var values: Array = []
			for column: int in 8: values.append(3.0 if row == column else (0.2 if absi(row-column)==1 else 0.0))
			matrix.append(values); rhs.append((-1.0 if row%2==0 else 1.0)*(row+1))
		var actual: PackedFloat64Array = _bounded_step(context,parameters,matrix,rhs)
		var expected: PackedFloat64Array = _legacy_eight_parameter_step(context,parameters,matrix,rhs)
		_check_native(actual.size() == 8 and actual == expected, "old two-digit bounded-step equality, lower/upper/interior trial " + str(trial))
	_legacy_layout = false

## Frozen pre-generalization active-bound policy: six angles, offsets 6/7.
## This intentionally retains fixed indices to detect layout regression.
func _legacy_eight_parameter_step(context: Dictionary, parameters: Array, matrix: Array, rhs: PackedFloat64Array) -> PackedFloat64Array:
	var constrained: Array = matrix.duplicate(true)
	var target: PackedFloat64Array = rhs.duplicate()
	var fixed: Dictionary = {}
	for pass_index: int in parameters.size()+1:
		var step: PackedFloat64Array = _linear_solve(constrained,target)
		if step.is_empty(): return step
		var added: bool = false
		for index: int in parameters.size():
			if index in [6,7] or fixed.has(index): continue
			var snapshot: Dictionary = context.adapter.digit_inputs[DIGITS[index/3]].snapshot
			var low: float = snapshot.min_angles_rad[index%3]
			var high: float = snapshot.max_angles_rad[index%3]
			if not ((parameters[index]<=low+1.0e-8 and step[index]<0.0) or (parameters[index]>=high-1.0e-8 and step[index]>0.0)): continue
			fixed[index]=true; added=true
			for j: int in parameters.size(): constrained[index][j]=0.0; constrained[j][index]=0.0
			constrained[index][index]=1.0; target[index]=0.0
		if not added: return step
	return []
