extends "res://tools/grip_plane_proof/run_shared_hand_closure_proof.gd"

var _gate_checks: int = 0
var _gate_failures: Array[String] = []
var _gate_final_mode: String = "valid"
var _gate_final_calls: int = 0
var _gate_cases: Array[Dictionary] = []


## Synthetic gate verification only. The inherited deferred _run invokes this
## override; _evaluate below supplies numeric fixtures, never a skeleton/scene.
func _run() -> void:
	_test_frame_gate()
	_test_object_source_gate()
	_test_trace_paths()
	_test_seed_order()
	_test_final_result_propagation()
	var report: Dictionary = {"schema": "shared_hand_closure_gate_verifier_v1", "ok": _gate_failures.is_empty(),
		"checks": _gate_checks, "failures": _gate_failures, "finalization_cases": _gate_cases,
		"scope": "synthetic_provenance_sort_and_failure_propagation_gates_only",
		"source_geometry_solved": false, "production_pose_written": false, "actual_3d_grip_verified": false}
	var path: String = "C:/WORKSPACE/test_artifacts/verify_shared_hand_closure_gates_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write shared hand gate verifier report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("SHARED_HAND_GATES_RESULT=" + path)
	print("SHARED_HAND_GATES_SUMMARY=" + JSON.stringify(report))
	quit(0 if _gate_failures.is_empty() else 1)


func _test_frame_gate() -> void:
	_gate_check(_same_frame(Transform3D.IDENTITY, Transform3D.IDENTITY), "matching finite frames accepted")
	var shifted: Transform3D = Transform3D.IDENTITY
	shifted.origin.x = 0.001
	_gate_check(not _same_frame(shifted, Transform3D.IDENTITY), "different finite frames rejected")
	var invalid: Transform3D = Transform3D.IDENTITY
	invalid.origin.x = NAN
	_gate_check(not _same_frame(invalid, Transform3D.IDENTITY) and not _same_frame(Transform3D.IDENTITY, invalid), "NaN translation rejected in either operand")
	invalid = Transform3D(Basis(Vector3(NAN, 0.0, 0.0), Vector3.UP, Vector3.BACK), Vector3.ZERO)
	_gate_check(not _same_frame(invalid, invalid), "matching nonfinite basis cannot pass a frame comparison")
	invalid = Transform3D.IDENTITY
	invalid.origin.z = INF
	_gate_check(not _same_frame(invalid, invalid), "matching infinite translations rejected")


func _test_object_source_gate() -> void:
	var object: Dictionary = {"origin_record": {"origin_id": &"FixtureMesh"},
		"weapon_origin_record": {"origin_id": &"FixtureWeapon"}, "local_faces_origin_id": &"FixtureMesh",
		"local_faces": PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP]),
		"mesh_to_world": Transform3D.IDENTITY, "weapon_to_world": Transform3D.IDENTITY}
	var before: PackedByteArray = var_to_bytes(object)
	_gate_check(bool(_validate_object_source(object).get("valid", false)), "named finite source triangle passes preliminary gate")
	var wrong_origin: Dictionary = object.duplicate(true)
	wrong_origin.local_faces_origin_id = &"DifferentMesh"
	var rejected: Dictionary = _prepare(null, {"object": wrong_origin})
	_gate_check(not rejected.get("valid", false) and rejected.get("reason") == "local_faces_origin_does_not_match_object_frame", "prepare rejects mismatched face origin before using anatomy or candidate builder")
	var missing_origin: Dictionary = object.duplicate(true)
	missing_origin.erase("local_faces_origin_id")
	_gate_check(not _validate_object_source(missing_origin).get("valid", false), "missing face origin rejected")
	var incomplete_faces: Dictionary = object.duplicate(true)
	incomplete_faces.local_faces = PackedVector3Array([Vector3.ZERO, Vector3.UP])
	_gate_check(not _validate_object_source(incomplete_faces).get("valid", false), "incomplete triangle rejected")
	var nonfinite_faces: Dictionary = object.duplicate(true)
	nonfinite_faces.local_faces[1] = Vector3(INF, 0.0, 0.0)
	_gate_check(not _validate_object_source(nonfinite_faces).get("valid", false), "nonfinite local vertex rejected")
	var nonfinite_frame: Dictionary = object.duplicate(true)
	nonfinite_frame.mesh_to_world = Transform3D(Basis.IDENTITY, Vector3(NAN, 0.0, 0.0))
	_gate_check(not _validate_object_source(nonfinite_frame).get("valid", false), "nonfinite mesh frame rejected")
	_gate_check(var_to_bytes(object) == before, "object gate leaves original source packet unchanged")


func _test_trace_paths() -> void:
	_gate_check(_workspace_trace_path("C:/WORKSPACE/test_artifacts/grip_placement_trace_hand_right_2026-09-18T02-30-57.bin"), "known workspace trace path admitted")
	for path: String in ["relative.bin", "C:/WORKSPACE/test_artifacts_extra/a.bin", "C:/WORKSPACE/test_artifacts/../a.bin", "C:/WORKSPACE/test_artifacts/a.bin:stream.bin", "C:/WORKSPACE/test_artifacts/a.exe", "C:/different_workspace/a.bin"]:
		_gate_check(not _workspace_trace_path(path), "reject unsafe or nontrace path: " + path)
	# No filesystem links are created for this proof. The established helper
	# checks every existing path component with DirAccess.is_link before opening.


func _test_seed_order() -> void:
	var samples: Array[Dictionary] = []
	for index: int in range(6):
		var sample: Dictionary = _gate_sample([float(index)], 0.0)
		# Successive depths straddle the old pairwise tolerance; exact sorting
		# must remain transitive despite opposed contact-error preference.
		sample.known_excess_depth_lower_m = float(index % 3) * 0.00000075
		sample.target_error_upper_sum_m = float(5 - index) * 0.000000075
		samples.append(sample)
	for a: Dictionary in samples:
		_gate_check(not _seed_less(a, a), "strict seed sort is irreflexive")
		for b: Dictionary in samples:
			_gate_check(not (_seed_less(a, b) and _seed_less(b, a)), "strict seed sort is asymmetric")
			for c: Dictionary in samples:
				if _seed_less(a, b) and _seed_less(b, c):
					_gate_check(_seed_less(a, c), "strict seed sort remains transitive across tolerance boundaries")
	var forward: Array[Dictionary] = samples.duplicate(true)
	var backward: Array[Dictionary] = samples.duplicate(true)
	backward.reverse()
	forward.sort_custom(_seed_less)
	backward.sort_custom(_seed_less)
	_gate_check(forward == backward, "seed order is independent of input reversal")
	var first: Dictionary = _gate_sample([0.0], 0.0)
	var second: Dictionary = _gate_sample([1.0], 0.0)
	_gate_check(_seed_less(first, second) and not _seed_less(second, first), "equal seed scores use parameter tuple tie-break")
	var barely_different: Dictionary = first.duplicate(true)
	barely_different.target_error_upper_sum_m = 0.00000005
	_gate_check(not _better(first, barely_different), "local improvement retains existing 0.1 micrometre score tolerance")


func _test_final_result_propagation() -> void:
	var context: Dictionary = _gate_context()
	for mode: String in ["valid", "initial", "selected", "both"]:
		_gate_final_mode = mode
		_gate_final_calls = 0
		var result: Dictionary = _search(context)
		_gate_check(_gate_final_calls == 2, mode + ": both final geometry requests occur")
		_gate_check(bool(result.get("valid", false)) == (mode == "valid"), mode + ": search validity reflects final evaluation failures")
		var expected: Array[String] = []
		if mode in ["initial", "both"]: expected.append("initial")
		if mode in ["selected", "both"]: expected.append("selected")
		_gate_check(result.get("failed_final_poses") == expected, mode + ": failing final poses are identified")
		if mode != "valid":
			_gate_check(result.get("reason") == "final_geometry_reevaluation_failed", mode + ": top-level reason preserves failure status")
		for pose: String in expected:
			_gate_check(result.get(pose, {}).get("reason") == "injected_" + pose + "_failure", mode + ": underlying " + pose + " failure retained")
		_gate_cases.append({"mode": mode, "valid": result.get("valid"), "failed_final_poses": result.get("failed_final_poses"), "mock_evaluations": _evaluations})


func _evaluate(_context: Dictionary, parameters: Array, keep_geometry: bool = false) -> Dictionary:
	if keep_geometry:
		_gate_final_calls += 1
		var pose: String = "initial" if _gate_final_calls == 1 else "selected"
		if _gate_final_mode == pose or _gate_final_mode == "both":
			return {"valid": false, "reason": "injected_" + pose + "_failure"}
	else:
		_evaluations += 1
	var error: float = 0.0
	for value: float in parameters:
		error += value * value
	return _gate_sample(parameters, error)


func _gate_sample(parameters: Array, error: float) -> Dictionary:
	return {"valid": true, "parameters": parameters.duplicate(), "digits": [],
		"known_excess_depth_lower_m": 0.0, "exceeding_known_segment_count": 0,
		"unresolved_known_segment_count": 0, "missing_required_contact_regions": 0,
		"target_error_upper_sum_m": error, "unassigned_skin_depth_upper_m": 0.0, "grip_accepted": false}


func _gate_context() -> Dictionary:
	var snapshot: Dictionary = {"preferred_angles_rad": [0.5, 0.5, 0.5], "min_angles_rad": [-1.0, -1.0, -1.0], "max_angles_rad": [1.0, 1.0, 1.0]}
	return {"slot": &"hand_right", "adapter": {"digit_inputs": {&"middle": {"snapshot": snapshot}, &"thumb": {"snapshot": snapshot}},
		"angle_convention": &"synthetic_fixture", "base_packet": {"machine_to_world": Transform3D.IDENTITY}},
		"guide_initial_radius_m": 0.05, "preparation_ms": 0.0, "weapon_to_world": Transform3D.IDENTITY,
		"station_axis_world": Vector3.UP, "translation_u_world": Vector3.RIGHT, "translation_v_world": Vector3.BACK}


func _gate_check(condition: bool, label: String) -> void:
	_gate_checks += 1
	if not condition:
		_gate_failures.append(label)
		push_error(label)
