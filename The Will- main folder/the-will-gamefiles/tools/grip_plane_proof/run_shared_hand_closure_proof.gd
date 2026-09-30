extends SceneTree

const SharedGripAcquisition = preload("res://runtime/player/grip/handle_grip_acquisition.gd")

const Store = preload("res://tools/grip_plane_proof/character_hand_anatomy_store.gd")
const OldInputs = preload("res://tools/grip_plane_proof/run_prepared_skin_contact_proof.gd")
const Candidate = preload("res://tools/grip_plane_proof/prepared_hand_candidate_pose.gd")
const Observe = preload("res://tools/grip_plane_proof/prepared_grip_slice_contact.gd")
const HandSkin = preload("res://tools/grip_plane_proof/prepared_hand_skin_query.gd")
const Slicer = preload("res://tools/grip_plane_proof/slice_reachable_surface.gd")
const Depth = preload("res://tools/grip_plane_proof/planar_skin_overlap_budget.gd")
const Centroid = preload("res://core/resolvers/primary_grip_seat_resolver.gd")
const Profile = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const DIGITS: Array[StringName] = [&"middle", &"thumb"]
const ROOT := &"RL_BoneRoot"
const MAX_EVALUATIONS := 224

var _builder := Candidate.new()
var _observer := Observe.new()
var _pose_cache: Dictionary = {}
var _slice_cache: Dictionary = {}
var _evaluations := 0
var _invalid: Dictionary = {}

## One ordered layout is shared by preparation, proposals and measurement.
## Overrides select already-prepared digits; they never synthesize anatomy.
func _selected_digits() -> Array[StringName]:
	return DIGITS

func _anatomy_source() -> Dictionary:
	return {"path":OldInputs.DEFINITION_PATH,"signature":OldInputs.SIGNATURE,"revision":"rest_middle_thumb_surface_measurements_v1"}

func _angle_count() -> int:
	return SharedGripAcquisition.op_shared_angle_count(self)

func _translation_u_index() -> int:
	return SharedGripAcquisition.op_shared_translation_u_index(self)

func _translation_v_index() -> int:
	return SharedGripAcquisition.op_shared_translation_v_index(self)

func _parameter_count() -> int:
	return SharedGripAcquisition.op_shared_parameter_count(self)

func _zero_parameters() -> Array:
	return SharedGripAcquisition.op_shared_zero_parameters(self)

func _angles_by_digit(parameters: Array) -> Dictionary:
	return SharedGripAcquisition.op_shared_angles_by_digit(self, parameters)

func _required_digit_contacts() -> Array:
	return SharedGripAcquisition.op_shared_required_digit_contacts(self)

func _required_contact_keys() -> Array:
	return SharedGripAcquisition.op_shared_required_contact_keys(self)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var anatomy: Dictionary = _anatomy_source()
	for key: String in ["path","signature","revision"]:
		if not anatomy.get(key) is String or str(anatomy[key]).is_empty():
			push_error("Missing explicit anatomy source "+key); quit(1); return
	var loaded: Dictionary = Store.new().load_matching(anatomy.path, anatomy.signature, anatomy.revision)
	if not loaded.get("valid", false): push_error(str(loaded)); quit(1); return
	var started := Time.get_ticks_usec()
	var report := {"schema": "shared_hand_closure_proof_v1", "cases": [], "failures": [],
		"anatomy_signature": loaded.resource.source_signature, "production_pose_written": false,
		"grip_accepted": false, "palm_contact_verified": false, "arm_realization_verified": false,
		"actual_3d_grip_verified": false, "handle_percent_positioning_changed": false,
		"scope": "combined_middle_thumb_with_one_transverse_hand_translation" if _selected_digits() == DIGITS else "combined_selected_digits_with_one_transverse_hand_translation",
		"palm_overlap_policy_applied": false, "independent_membrane_curvature_implemented": false}
	report.merge(_report_extensions(), true)
	report["selected_digits"] = _selected_digits().duplicate()
	var paths := OS.get_environment("THE_WILL_GRIP_PLACEMENT_PATHS").split(";", false)
	if paths.is_empty(): report.failures.append("missing_explicit_workspace_traces")
	for requested: String in paths:
		var path := requested.replace("\\", "/").simplify_path()
		if not _workspace_trace_path(path):
			report.failures.append("invalid_trace_path"); continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null: report.failures.append("unreadable_trace"); continue
		var trace: Variant = file.get_var(false); file.close()
		if not trace is Dictionary or trace.get("schema") != "grip_placement_trace_v1" or not trace.get("valid", false) or not trace.get("validation", {}).get("valid", false) or not trace.get("capture_errors", []).is_empty() or trace.get("anatomy_signature") != loaded.resource.source_signature:
			report.failures.append("invalid_trace"); continue
		var chosen: Dictionary = {}
		for transaction: Dictionary in trace.transactions:
			if transaction.slot == trace.slot and transaction.get("result", {}).get("applied", false) and not transaction.get("finger_inputs", []).is_empty(): chosen = transaction
		if chosen.is_empty(): report.failures.append("no_accepted_seat"); continue
		var stage: Dictionary = chosen.finger_inputs[-1]
		if not stage.get("valid", false) or stage.get("stage") != &"finger_solve_input" or stage.get("transaction_serial") != chosen.serial or stage.posed_character.get("transaction_serial") != chosen.serial or stage.posed_character.get("capture_stage") != stage.stage or stage.posed_character.get("engine_process_frame") != stage.get("engine_process_frame"):
			report.failures.append("mismatched_capture_epoch"); continue
		var context := _prepare(loaded.resource, stage)
		if not context.get("valid", false): report.failures.append(context); continue
		# Native SkeletonModifier3D proofs must capture modification_processed.
		# Awaiting a synchronous proof result returns immediately in GDScript.
		var result: Dictionary = await _search(context)
		result["source_trace"] = path
		result["source_trace_sha256"] = FileAccess.get_sha256(path)
		result["source_transaction"] = chosen.serial
		report.cases.append(result)
		if not result.get("valid", false): report.failures.append(result.get("reason", "failed_shared_search"))
		print("SHARED_HAND_CASE=" + JSON.stringify(_json({"slot": context.slot, "evaluations": result.get("evaluation_count"), "total_ms": result.get("total_search_ms"), "selected": _brief(result.get("selected", {}))})))
	report["ok"] = report.failures.is_empty()
	report["total_diagnostic_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	var path := "C:/WORKSPACE/test_artifacts/" + _report_stem() + "_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output == null: push_error("Cannot save shared proof"); quit(1); return
	output.store_string(JSON.stringify(_json(report), "\t")); output.close()
	print("SHARED_HAND_RESULT=" + path)
	print("SHARED_HAND_SUMMARY=" + JSON.stringify({"ok": report.ok, "failures": report.failures, "total_ms": report.total_diagnostic_ms}))
	quit(0 if report.ok else 1)

func _report_extensions() -> Dictionary:
	return {}

func _report_stem() -> String:
	return "shared_hand_closure"

func _observe_slice(context: Dictionary, candidate: Dictionary, slice: Dictionary, digit: StringName, keep_geometry: bool) -> Dictionary:
	return _observer.evaluate(context.observations[digit], candidate, slice.plane, slice.origin_id, slice.target, context.guide_initial_radius_m, keep_geometry)

func _prepare(definition: Resource, stage: Dictionary) -> Dictionary:
	return SharedGripAcquisition.op_shared_prepare(self,definition,stage)

func _targets(context: Dictionary, candidate: Dictionary, translation: Array) -> Dictionary:
	return SharedGripAcquisition.op_shared_targets(self, context,candidate,translation)

func _evaluate(context: Dictionary, parameters: Array, keep_geometry: bool = false) -> Dictionary:
	var key := var_to_bytes(parameters).hex_encode()
	if not keep_geometry and _pose_cache.has(key): return _pose_cache[key]
	if not keep_geometry and _evaluations >= MAX_EVALUATIONS: return {}
	if not keep_geometry: _evaluations += 1
	var started := Time.get_ticks_usec()
	var angles := _angles_by_digit(parameters)
	var translation: Vector3 = context.translation_u_world * float(parameters[_translation_u_index()]) + context.translation_v_world * float(parameters[_translation_v_index()])
	var candidate: Dictionary = _builder.evaluate(context.adapter, angles, translation, ROOT)
	if not candidate.get("valid", false): return _bad(candidate)
	var targets := _targets(context, candidate, [parameters[_translation_u_index()],parameters[_translation_v_index()]])
	if not targets.get("valid", false): return _bad(targets)
	var result := {"valid": true, "parameters": parameters.duplicate(), "translation_world": translation,
		"translation_world_origin_id": ROOT, "axial_translation_m": translation.dot(context.station_axis_world),
		"hand_to_world": candidate.hand_to_world, "hand_to_world_origin_id": ROOT, "pose_id": candidate.pose_packet.pose_id,
		"digits": [], "known_excess_depth_lower_m": 0.0, "exceeding_known_segment_count": 0,
		"unresolved_known_segment_count": 0, "missing_required_contact_regions": 0,
		"target_error_upper_sum_m": 0.0, "unassigned_skin_depth_upper_m": 0.0,
		"candidate_pose_ms": candidate.evaluation_ms, "grip_accepted": false,
		"arm_realization_verified": false, "palm_contact_verified": false, "actual_3d_grip_verified": false}
	for digit: StringName in _selected_digits():
		var slice: Dictionary = targets.digits[digit]
		var observation: Dictionary = _observe_slice(context, candidate, slice, digit, keep_geometry)
		if not observation.get("valid", false): return _bad(observation)
		if observation.pose_id != result.pose_id: return _bad({"reason": "digit_observation_pose_epoch_mismatch"})
		observation["digit"] = digit
		observation["slice_center_m"] = slice.center
		observation["plane_to_world"] = slice.plane
		observation["plane_origin_id"] = slice.origin_id
		if keep_geometry:
			observation["target_polygon_m"] = slice.polygon
			observation["section_targets_m"] = context.observations[digit].targets_m
			observation["section_caps_m"] = context.observations[digit].caps_m
		result.digits.append(observation)
		result.known_excess_depth_lower_m = maxf(result.known_excess_depth_lower_m, observation.known_excess_depth_lower_m)
		for field: String in ["exceeding_known_segment_count", "unresolved_known_segment_count", "missing_required_contact_regions", "target_error_upper_sum_m"]: result[field] += observation[field]
		result.unassigned_skin_depth_upper_m = maxf(result.unassigned_skin_depth_upper_m, observation.unassigned_skin_depth_upper_m)
	if absf(result.axial_translation_m) > 0.000001: return _bad({"reason": "authored_station_changed"})
	if keep_geometry: result["pose_origin_records"] = candidate.pose_packet.origin_records
	result["trial_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	if not keep_geometry:
		_pose_cache[key] = result
	return result

func _search(context: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	_pose_cache.clear(); _slice_cache.clear(); _invalid.clear(); _evaluations = 0
	var initial_params: Array[float] = []
	initial_params.assign(_zero_parameters())
	var initial := _evaluate(context, initial_params)
	if not initial.get("valid", false): return initial
	var seeds: Array[Dictionary] = []
	var best := initial
	# Seed complete shared poses, retaining folding alternatives before local
	# refinement. This is a bounded static search, not a collision-free motion path.
	for middle_fraction: float in [0.0,0.5,1.0]:
		for thumb_fraction: float in [0.0,0.5,1.0]:
			var values := initial_params.duplicate()
			for index: int in range(_angle_count()):
				var digit: StringName = _selected_digits()[index / 3]
				values[index] = float(context.adapter.digit_inputs[digit].snapshot.preferred_angles_rad[index % 3]) * (thumb_fraction if digit == &"thumb" else middle_fraction)
			var sample := _evaluate(context, values)
			if sample.get("valid", false):
				seeds.append(sample)
				if _better(sample, best): best = sample
	seeds.sort_custom(_seed_less)
	var retained: Array = seeds.slice(0, mini(3,seeds.size()))
	for seed: Dictionary in retained:
		for offset: Vector2 in [Vector2(0.25,0),Vector2(-0.25,0),Vector2(0,0.25),Vector2(0,-0.25)]:
			var values: Array = seed.parameters.duplicate()
			values[_translation_u_index()] = offset.x * float(context.guide_initial_radius_m)
			values[_translation_v_index()] = offset.y * float(context.guide_initial_radius_m)
			var sample := _evaluate(context, values)
			if sample.get("valid", false):
				seeds.append(sample)
				if _better(sample,best): best = sample
	seeds.sort_custom(_seed_less)
	retained = seeds.slice(0, mini(2,seeds.size()))
	var history: Array = []
	for seed: Dictionary in retained:
		var current: Dictionary = seed
		for level: int in range(5):
			var next := current
			var directions: Array = []
			for index: int in range(_parameter_count()):
				for sign_value: float in [1.0,-1.0]:
					var direction: Array[float] = []
					direction.assign(_zero_parameters())
					direction[index] = sign_value
					directions.append(direction)
			for digit_index: int in _selected_digits().size():
				for sign_value: float in [1.0,-1.0]:
					var closure: Array = _zero_parameters()
					for joint: int in 3: closure[digit_index * 3 + joint] = sign_value
					directions.append(closure)
			for direction: Array in directions:
				if _evaluations >= MAX_EVALUATIONS: break
				var values: Array = current.parameters.duplicate()
				for index: int in range(_angle_count()):
					var snapshot: Dictionary = context.adapter.digit_inputs[_selected_digits()[index / 3]].snapshot
					var joint: int = index % 3
					var step: float = (float(snapshot.max_angles_rad[joint]) - float(snapshot.min_angles_rad[joint])) / (8.0 * pow(2.0,level))
					values[index] = clampf(values[index] + direction[index] * step, snapshot.min_angles_rad[joint], snapshot.max_angles_rad[joint])
				for index: int in [_translation_u_index(),_translation_v_index()]: values[index] = clampf(values[index] + direction[index] * float(context.guide_initial_radius_m) / (4.0 * pow(2.0,level)), -context.guide_initial_radius_m, context.guide_initial_radius_m)
				var sample := _evaluate(context, values)
				if sample.get("valid", false) and _better(sample,next): next = sample
			current = next
			if _better(current,best): best = current
			history.append(_brief(current))
			print("SHARED_HAND_PROGRESS=" + JSON.stringify({"slot":context.slot,"evaluations":_evaluations,"error_m":best.target_error_upper_sum_m}))
	var final_initial: Dictionary = _evaluate(context, initial_params, true)
	var final_selected: Dictionary = _evaluate(context, best.parameters, true)
	var failed_final_poses: Array[String] = []
	if not bool(final_initial.get("valid", false)): failed_final_poses.append("initial")
	if not bool(final_selected.get("valid", false)): failed_final_poses.append("selected")
	return {"valid": failed_final_poses.is_empty(), "slot": context.slot,
		"reason": "" if failed_final_poses.is_empty() else "final_geometry_reevaluation_failed",
		"failed_final_poses": failed_final_poses,
		"initial": final_initial, "selected": final_selected, "refinement_history": history,
		"evaluation_count": _evaluations, "evaluation_budget": MAX_EVALUATIONS, "invalid_candidates": _invalid,
		"slice_cache_entries": _slice_cache.size(), "source_stage": "post_existing_surface_seat_finger_input",
		"angle_convention": context.adapter.angle_convention, "weapon_to_world":context.weapon_to_world,
		"vectors_origin_id":ROOT,"station_axis_world":context.station_axis_world,
		"translation_u_world":context.translation_u_world,"translation_v_world":context.translation_v_world,
		"machine_to_world":context.adapter.base_packet.machine_to_world,
		"guide_initial_radius_m":context.guide_initial_radius_m,"preparation_ms":context.preparation_ms,
		"total_search_ms":float(Time.get_ticks_usec()-started)/1000.0,
		"termination":"bounded_multi_start_search_not_infeasibility_proof","grip_accepted":false}

func _seed_less(a: Dictionary, b: Dictionary) -> bool:
	# Sorting requires a strict ordering. Pairwise epsilon ties in _better are
	# intentionally retained for local improvement, but are not transitive and
	# must not govern sort_custom. Identical metrics use the full parameter tuple.
	for key: String in ["known_excess_depth_lower_m", "exceeding_known_segment_count", "unresolved_known_segment_count", "missing_required_contact_regions"]:
		if a[key] != b[key]: return a[key] < b[key]
	var a_error: float = float(a.target_error_upper_sum_m) + float(a.unassigned_skin_depth_upper_m)
	var b_error: float = float(b.target_error_upper_sum_m) + float(b.unassigned_skin_depth_upper_m)
	if a_error != b_error: return a_error < b_error
	var a_parameters: Array = a.parameters
	var b_parameters: Array = b.parameters
	for index: int in range(mini(a_parameters.size(), b_parameters.size())):
		if a_parameters[index] != b_parameters[index]: return a_parameters[index] < b_parameters[index]
	return a_parameters.size() < b_parameters.size()

func _better(a: Dictionary, b: Dictionary) -> bool:
	if absf(a.known_excess_depth_lower_m - b.known_excess_depth_lower_m) > 0.000001: return a.known_excess_depth_lower_m < b.known_excess_depth_lower_m
	for key: String in ["exceeding_known_segment_count","unresolved_known_segment_count","missing_required_contact_regions"]:
		if a[key] != b[key]: return a[key] < b[key]
	return float(a.target_error_upper_sum_m) + float(a.unassigned_skin_depth_upper_m) < float(b.target_error_upper_sum_m) + float(b.unassigned_skin_depth_upper_m) - 0.0000001

func _bad(details: Dictionary) -> Dictionary:
	var reason := str(details.get("reason", "invalid_candidate"))
	_invalid[reason] = int(_invalid.get(reason,0)) + 1
	return {"valid":false,"reason":reason}

func _brief(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	result.erase("pose_origin_records")
	for digit: Dictionary in result.get("digits",[]):
		for key: String in ["skin_segments","depth_measurements","contact_depth_measurements","pose_origin_records","target_polygon_m","contact_target_polygon_m"]: digit.erase(key)
	return result

func _same_frame(a: Transform3D,b: Transform3D) -> bool:
	return SharedGripAcquisition.op_shared_same_frame(self, a,b)

func _validate_object_source(object: Dictionary) -> Dictionary:
	return SharedGripAcquisition.op_shared_validate_object_source(self, object)

func _workspace_trace_path(path: String) -> bool:
	# Same checked-directory policy as diagnose_coherent_grip_placement. Keep
	# it before FileAccess; links/junctions and alternate streams are not inputs.
	if path != path.replace("\\", "/").simplify_path(): return false
	if not path.is_absolute_path() or not path.to_lower().begins_with("c:/workspace/test_artifacts/") or path.get_extension().to_lower() != "bin" or path.substr(3).contains(":"):
		return false
	var directory: DirAccess = DirAccess.open("C:/WORKSPACE")
	if directory == null or directory.is_link("C:/WORKSPACE"): return false
	var current: String = "C:/WORKSPACE"
	for component: String in path.substr("C:/WORKSPACE/".length()).split("/", false):
		current = current.path_join(component)
		if directory.is_link(current): return false
	return true

func _json(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for key: Variant in value: out[str(key)] = _json(value[key])
		return out
	if value is Vector2: return [value.x,value.y]
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Transform3D: return {"origin":_json(value.origin),"basis":[_json(value.basis.x),_json(value.basis.y),_json(value.basis.z)]}
	if value is float and not is_finite(value): return null
	if value is Array or value is PackedVector2Array or value is PackedVector3Array or value is PackedFloat64Array or value is PackedFloat32Array or value is PackedInt32Array or value is PackedStringArray:
		var out: Array = []
		for item: Variant in value: out.append(_json(item))
		return out
	return value

func _is_cancelled() -> bool:
	return false

func _progress_update(_values: Dictionary) -> void:
	pass

func _retain_history() -> bool:
	return true

func _runtime_work(method: StringName, arguments: Array) -> Dictionary:
	return callv(method,arguments)
