extends SceneTree

## Repeatable actual-rig allocator benchmark. A declared rigid Hand/prop binding
## stands in for an already acquired grip; no finger acquisition or saved skill
## is touched. Binary fixtures preserve the exact numeric inputs across runs.
const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const Adapter = preload("res://runtime/player/combat_weapon_motion_rig_adapter.gd")
const Allocator = preload("res://core/resolvers/combat_weapon_motion_allocator.gd")
const BACKEND_PATH := "res://core/resolvers/combat_motion_math_backend.gd"
const FIXTURE_REVISION := "idle_motion_native_benchmark_v1"
const COMPARE_Q_RADIANS := 0.00001
const COMPARE_CONSTRAINT := 0.00001
const COMPARE_POSITION_M := 0.000005
const COMPARE_ANGLE_RADIANS := 0.00008726646 # 0.005 degrees, below runtime cap.
var output_dir := "C:/WORKSPACE/godot_runs/motion_native_performance_20261108/script"
var fixture_path := ""
var comparison_path := ""
var native_enabled := false
var cached_storage := true
var clearance_enabled := false
var commit_enabled := false
var selected_case := ""
var backend: Script
var rig: PlayerHumanoidRig
var skeleton: Skeleton3D
var fixture: Dictionary = {}
var records: Array[Dictionary] = []
var checks: Array[Dictionary] = []

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="): output_dir = argument.trim_prefix("--out-dir=")
		elif argument.begins_with("--fixture="): fixture_path = argument.trim_prefix("--fixture=")
		elif argument.begins_with("--compare="): comparison_path = argument.trim_prefix("--compare=")
		elif argument.begins_with("--native="): native_enabled = argument.trim_prefix("--native=") == "true"
		elif argument.begins_with("--cached-storage="): cached_storage = argument.trim_prefix("--cached-storage=") == "true"
		elif argument.begins_with("--clearance="): clearance_enabled = argument.trim_prefix("--clearance=") == "true"
		elif argument.begins_with("--commit="): commit_enabled = argument.trim_prefix("--commit=") == "true"
		elif argument.begins_with("--case="): selected_case = argument.trim_prefix("--case=")
	call_deferred("_run")

func _run() -> void:
	if ResourceLoader.exists(BACKEND_PATH):
		backend = load(BACKEND_PATH) as Script
		backend.call("configure_native", native_enabled)
		backend.call("configure_profiling", true)
	elif native_enabled:
		_check(false, "requested_native_backend_exists")
		_finish()
		return
	rig = RigScene.instantiate() as PlayerHumanoidRig
	root.add_child(rig)
	await process_frame
	await process_frame
	rig.set_authoring_preview_mode_enabled(true)
	rig.reset_authoring_preview_baseline_pose()
	rig.set_process(false)
	rig.set_physics_process(false)
	for tree: Node in rig.find_children("*", "AnimationTree", true, false):
		(tree as AnimationTree).active = false
	skeleton = rig.skeleton
	_check(skeleton != null, "actual_josie_skeleton_present")
	if skeleton == null:
		_finish()
		return
	if fixture_path.is_empty():
		fixture = _capture_fixture()
	else:
		fixture = _read_binary(fixture_path)
		_check(fixture.get("revision", "") == FIXTURE_REVISION, "binary_fixture_revision")
		if fixture.get("revision", "") != FIXTURE_REVISION:
			_finish()
			return
	_check(fixture.get("profiles", {}) == _profiles(), "same_anatomical_profile_contract")
	_check(fixture.get("bone_names", []) == _bone_names(), "same_named_bone_layout")
	_check(fixture.get("rest_poses", []) == _rest_poses(), "same_imported_rest_transforms")
	if not _checks_passed():
		_finish()
		return
	var previous: Dictionary = _read_binary(comparison_path) if not comparison_path.is_empty() else {}
	if not comparison_path.is_empty():
		_check(previous.get("fixture_sha256", "") == _digest(fixture), "comparison_uses_identical_binary_fixture")
		_check(bool(previous.get("forearm_clearance_enabled", false)) == clearance_enabled and bool(previous.get("commit_enabled", false)) == commit_enabled,
			"comparison_uses_identical_clearance_and_commit_policy")
	var chosen := 0
	for specification: Dictionary in fixture.cases:
		if not selected_case.is_empty() and specification.id != selected_case:
			continue
		chosen += 1
		_run_case(specification, previous)
	_check(chosen > 0, "selected_benchmark_has_requests")
	_finish()

func _capture_fixture() -> Dictionary:
	var positions := PackedVector3Array()
	var rotations: Array[Quaternion] = []
	var scales := PackedVector3Array()
	for index: int in skeleton.get_bone_count():
		positions.append(skeleton.get_bone_pose_position(index))
		rotations.append(skeleton.get_bone_pose_rotation(index))
		scales.append(skeleton.get_bone_pose_scale(index))
	var data := {"revision": FIXTURE_REVISION, "bone_names": _bone_names(), "rest_poses": _rest_poses(),
		"positions": positions, "rotations": rotations, "scales": scales,
		"rig_world": rig.global_transform, "skeleton_world": skeleton.global_transform,
		"profiles": _profiles(), "rig_limits": {}, "caches": {}, "cases": []}
	for property: String in ["standing_height_meters", "authoring_shoulder_min_plane_angle_degrees", "authoring_shoulder_max_plane_angle_degrees", "authoring_elbow_min_plane_angle_degrees", "authoring_elbow_max_plane_angle_degrees"]:
		data.rig_limits[property] = rig.get(property)
	for property: String in ["_wrist_motion_states", "_shoulder_motion_states", "_wrist_motion_failures"]:
		data.caches[property] = (rig.get(property) as Dictionary).duplicate(true)
	# Request axes come from named actual body/hand frames, never a guessed
	# imported XYZ convention. All inputs are then persisted as world transforms.
	for side: String in ["R", "L"]:
		var slot := &"hand_right" if side == "R" else &"hand_left"
		var hand := _bone_world("CC_Base_" + side + "_Hand")
		var shoulder := _bone_world("CC_Base_" + side + "_Upperarm")
		var chest := _bone_world("CC_Base_Spine02")
		var calibration: Dictionary = rig.capture_shoulder_constraint_calibration(slot)
		var chest_axes: Basis = chest.basis.orthonormalized() * (calibration.chest_anatomical_in_bone as Basis)
		var prop := hand * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.0))
		var binding := prop.affine_inverse() * hand
		var outward := (hand.origin - shoulder.origin).normalized()
		data.cases.append(_translation_case(side + "_pommel_easy_20mm_up", slot, prop, binding, chest_axes.y * 0.02, true))
		data.cases.append(_translation_case(side + "_pommel_boundary_100mm_outward", slot, prop, binding, outward * 0.10, false))
		if side == "R":
			data.cases.append(_translation_case("R_pommel_complex_100mm_forward", slot, prop, binding, -chest_axes.z * 0.10, false))
			data.cases.append(_translation_case("R_pommel_complex_100mm_up", slot, prop, binding, chest_axes.y * 0.10, false))
			for degrees: float in [3.0, 45.0, -45.0]:
				var target_basis := Basis(hand.basis.x.normalized(), deg_to_rad(degrees)) * prop.basis
				data.cases.append({"id": "R_tip_%s_degrees" % degrees, "mode": "tip", "slot": slot,
					"previous_weapon": prop, "target_weapon": Transform3D(target_basis, prop.origin),
					"hand_in_weapon": binding, "contact_local": Vector3.ZERO,
					"expect_progress": absf(degrees) < 4.0, "demand_degrees": degrees})
	return data

func _translation_case(id: String, slot: StringName, prop: Transform3D, binding: Transform3D, displacement: Vector3, expect_progress: bool) -> Dictionary:
	var target := prop
	target.origin += displacement
	return {"id": id, "mode": "pommel", "slot": slot, "previous_weapon": prop,
		"target_weapon": target, "hand_in_weapon": binding, "contact_local": Vector3.ZERO,
		"expect_progress": expect_progress, "demand_m": displacement.length()}

func _restore_fixture() -> void:
	rig.global_transform = fixture.rig_world
	skeleton.global_transform = fixture.skeleton_world
	for property: String in fixture.rig_limits:
		rig.set(property, fixture.rig_limits[property])
	for index: int in skeleton.get_bone_count():
		skeleton.set_bone_pose_position(index, fixture.positions[index])
		skeleton.set_bone_pose_rotation(index, fixture.rotations[index])
		skeleton.set_bone_pose_scale(index, fixture.scales[index])
	for property: String in fixture.caches:
		rig.set(property, fixture.caches[property].duplicate(true))
	skeleton.force_update_all_bone_transforms()

func _run_case(specification: Dictionary, previous: Dictionary) -> void:
	_restore_fixture()
	var prop := Node3D.new()
	root.add_child(prop)
	prop.global_transform = specification.previous_weapon
	var request := {"mode": specification.mode, "weapon": prop, "primary_slot": specification.slot,
		"support_slot": StringName(), "previous_weapon": specification.previous_weapon,
		"target_weapon": specification.target_weapon, "contact_local": specification.contact_local,
		"hand_in_weapon_by_slot": {specification.slot: specification.hand_in_weapon}, "commit": commit_enabled,
		"policy": {"forearm_clearance_enabled": clearance_enabled, "trace_evaluation_phases": true,
			"cached_storage_readback": cached_storage}}
	var inspector := Adapter.new()
	var initialized: Dictionary = inspector._initialize(rig, request)
	_check(bool(initialized.get("valid", false)), specification.id + "_initializes", initialized)
	if not bool(initialized.get("valid", false)):
		prop.free()
		return
	var initial_evaluation: Dictionary = inspector._evaluate_kinematics(inspector.q)
	var initial_validation := Allocator.validate_with_start_allowance(inspector._allocator_input(), initial_evaluation, inspector.policy, inspector.start_allowance)
	_check(bool(initial_validation.get("valid", false)), specification.id + "_starts_from_accepted_binding", initial_validation)
	_check(Allocator._legal(inspector.q, initial_evaluation, inspector.lower, inspector.upper),
		specification.id + "_idle_is_raw_anatomically_legal", {"maximum_constraint": _maximum(PackedFloat64Array(initial_evaluation.get("constraints", [])))})
	var start := {"q": inspector.q.duplicate(), "lower": inspector.lower.duplicate(), "upper": inspector.upper.duplicate(),
		"groups": inspector.groups.duplicate(), "allowance": inspector.start_allowance.duplicate(true),
		"policy": inspector.policy.duplicate(true), "evaluation": _evaluation_snapshot(initial_evaluation),
		"calibrations": []}
	for arm: Dictionary in inspector.arms:
		start.calibrations.append({"slot": arm.slot, "shoulder": arm.shoulder_calibration,
			"wrist": arm.wrist_calibration, "clavicle": arm.clavicle_calibration})
	var before := _scene_snapshot(prop)
	var opposite_before := _opposite_arm_world_poses(specification.slot)
	if backend != null:
		backend.call("reset_backend_stats")
	var adapter := Adapter.new()
	var started := Time.get_ticks_usec()
	var result: Dictionary = adapter.allocate(rig, request)
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var backend_stats: Dictionary = backend.call("get_backend_stats") if backend != null else {}
	var timings: Dictionary = result.get("timings", adapter._timing_result()).duplicate(true)
	var accepted_values := PackedFloat64Array(result.get("accepted_q", adapter.q))
	var accepted_evaluation: Dictionary = adapter._evaluate_kinematics(accepted_values)
	var effective := Allocator.apply_start_allowance(accepted_evaluation, adapter.start_allowance)
	var constraint_max := _maximum(PackedFloat64Array(effective.get("constraints", [])))
	_check(Allocator._legal(accepted_values, effective, adapter.start_allowance.lower, adapter.start_allowance.upper),
		specification.id + "_accepted_pose_keeps_effective_constraints", {"maximum_constraint": constraint_max})
	var unchanged := before == _scene_snapshot(prop)
	if not commit_enabled:
		_check(unchanged, specification.id + "_read_only_scene_restored")
	elif bool(result.get("valid", false)):
		_check_committed_contact(specification.id, specification.slot, prop, specification.hand_in_weapon, opposite_before)
	var accepted_frame: Transform3D = result.get("accepted_weapon", specification.previous_weapon)
	var start_frame: Transform3D = specification.previous_weapon
	var actual_translation_m := accepted_frame.origin.distance_to(start_frame.origin)
	var actual_angle_degrees := rad_to_deg(_angle(accepted_frame.basis, start_frame.basis))
	if bool(specification.expect_progress):
		var measurable: bool = actual_translation_m > 0.001 if specification.mode == "pommel" else actual_angle_degrees > 0.5
		_check(bool(result.get("valid", false)) and float(result.get("task_scale", 0.0)) > 0.0 and measurable,
			specification.id + "_meaningful_easy_movement", {"status": result.get("status"), "reason": result.get("reason"), "task_scale": result.get("task_scale"),
				"actual_translation_m": actual_translation_m, "actual_angle_degrees": actual_angle_degrees})
	var compact := result.duplicate()
	for key: String in ["motion_adapter", "accepted_payload", "accepted_pose"]:
		compact.erase(key)
	var record := {"id": specification.id, "request": specification, "start": start,
		"result": compact, "elapsed_ms": elapsed_ms, "timings": timings, "backend_stats": backend_stats,
		"accepted_evaluation": _evaluation_snapshot(accepted_evaluation),
		"accepted_max_effective_constraint": constraint_max,
		"actual_translation_m": actual_translation_m, "actual_angle_degrees": actual_angle_degrees,
		"read_only_scene_restored": unchanged}
	if not previous.is_empty():
		var reference := _find_record(previous, specification.id)
		_check(not reference.is_empty(), specification.id + "_comparison_reference_exists")
		if not reference.is_empty():
			record["comparison"] = _compare_record(reference, record)
			_check(bool(record.comparison.equivalent), specification.id + "_native_preserves_reference_outcome", record.comparison)
	records.append(record)
	print("MOTION_NATIVE_BENCH %s native=%s status=%s scale=%.6f elapsed_ms=%.3f evals=%s" % [specification.id, native_enabled, result.get("status", ""), float(result.get("task_scale", 0.0)), elapsed_ms, timings.get("evaluate_count", 0)])
	prop.free()

func _evaluation_snapshot(evaluation: Dictionary) -> Dictionary:
	return {"valid": evaluation.get("valid", false), "weapon_frame": evaluation.get("weapon_frame", Transform3D.IDENTITY),
		"constraints": evaluation.get("constraints", PackedFloat64Array()), "constraint_reasons": evaluation.get("constraint_reasons", PackedStringArray()),
		"equalities": evaluation.get("equalities", PackedFloat64Array()),
		"equality_tolerances": evaluation.get("equality_tolerances", PackedFloat64Array()),
		"local_poses": evaluation.get("payload", {}).get("local_poses", []),
		"globals": evaluation.get("payload", {}).get("globals", []),
		"hand_frames": evaluation.get("payload", {}).get("hand_frames", {})}

func _compare_record(reference: Dictionary, current: Dictionary) -> Dictionary:
	var reference_start: Dictionary = reference.start.duplicate(true)
	var current_start: Dictionary = current.start.duplicate(true)
	# Evaluation is an output of the candidate backend, not an input contract.
	# Compare its numeric result separately, without requiring bit-identical FK.
	reference_start.erase("evaluation")
	current_start.erase("evaluation")
	# This is the explicit implementation choice being compared, not a change
	# to physical limits, control ownership, request or task-search policy.
	(reference_start.policy as Dictionary).erase("cached_storage_readback")
	(current_start.policy as Dictionary).erase("cached_storage_readback")
	var input_identical: bool = reference.request == current.request and reference_start == current_start
	var q_error := _array_error(reference.result.get("accepted_q", []), current.result.get("accepted_q", []))
	var constraint_error := _array_error(reference.accepted_evaluation.constraints, current.accepted_evaluation.constraints)
	var position_error := 0.0
	var angle_error := 0.0
	var a: Array = reference.accepted_evaluation.local_poses
	var b: Array = current.accepted_evaluation.local_poses
	if a.size() != b.size():
		position_error = INF
		angle_error = INF
	else:
		for index: int in a.size():
			position_error = maxf(position_error, (a[index] as Transform3D).origin.distance_to((b[index] as Transform3D).origin))
			angle_error = maxf(angle_error, _angle((a[index] as Transform3D).basis, (b[index] as Transform3D).basis))
	var weapon_a: Transform3D = reference.result.get("accepted_weapon", Transform3D.IDENTITY)
	var weapon_b: Transform3D = current.result.get("accepted_weapon", Transform3D.IDENTITY)
	var weapon_position_error := weapon_a.origin.distance_to(weapon_b.origin)
	var weapon_angle_error := _angle(weapon_a.basis, weapon_b.basis)
	var same_outcome: bool = reference.result.get("status", "") == current.result.get("status", "") and reference.result.get("reason", "") == current.result.get("reason", "")
	var scale_error := absf(float(reference.result.get("task_scale", 0.0)) - float(current.result.get("task_scale", 0.0)))
	var equivalent: bool = input_identical and same_outcome and scale_error <= 0.000001 and q_error <= COMPARE_Q_RADIANS \
		and constraint_error <= COMPARE_CONSTRAINT and position_error <= COMPARE_POSITION_M and angle_error <= COMPARE_ANGLE_RADIANS \
		and weapon_position_error <= COMPARE_POSITION_M and weapon_angle_error <= COMPARE_ANGLE_RADIANS
	return {"equivalent": equivalent, "inputs_identical": input_identical, "status_and_reason_identical": same_outcome,
		"task_scale_error": scale_error, "q_max_error_radians": q_error, "constraint_max_error": constraint_error,
		"local_position_max_error_m": position_error, "local_angle_max_error_degrees": rad_to_deg(angle_error),
		"weapon_position_error_m": weapon_position_error, "weapon_angle_error_degrees": rad_to_deg(weapon_angle_error),
		"baseline_elapsed_ms": reference.elapsed_ms, "current_elapsed_ms": current.elapsed_ms,
		"time_ratio_current_over_baseline": float(current.elapsed_ms) / maxf(float(reference.elapsed_ms), 0.000001),
		"baseline_evaluate_count": reference.timings.get("evaluate_count", 0), "current_evaluate_count": current.timings.get("evaluate_count", 0)}

func _scene_snapshot(prop: Node3D) -> Dictionary:
	var rotations: Array[Quaternion] = []
	for index: int in skeleton.get_bone_count(): rotations.append(skeleton.get_bone_pose_rotation(index))
	return {"rotations": rotations, "weapon_world": prop.global_transform,
		"wrist_cache": (rig.get("_wrist_motion_states") as Dictionary).duplicate(true),
		"shoulder_cache": (rig.get("_shoulder_motion_states") as Dictionary).duplicate(true)}

func _opposite_arm_world_poses(slot: StringName) -> Dictionary:
	var upper_id := skeleton.find_bone("CC_Base_L_Upperarm" if slot == &"hand_right" else "CC_Base_R_Upperarm")
	var result: Dictionary = {}
	for index: int in skeleton.get_bone_count():
		var ancestor := index
		while ancestor >= 0 and ancestor != upper_id:
			ancestor = skeleton.get_bone_parent(ancestor)
		if ancestor == upper_id:
			result[index] = skeleton.global_transform * skeleton.get_bone_global_pose(index)
	return result

func _check_committed_contact(id: String, slot: StringName, prop: Node3D, binding: Transform3D, opposite_before: Dictionary) -> void:
	skeleton.force_update_all_bone_transforms()
	var hand := _bone_world("CC_Base_R_Hand" if slot == &"hand_right" else "CC_Base_L_Hand")
	var expected := prop.global_transform * binding
	var position_error := hand.origin.distance_to(expected.origin)
	var angle_error := _angle(hand.basis, expected.basis)
	_check(position_error <= 0.00005 and angle_error <= deg_to_rad(0.025), id + "_committed_hand_prop_contact",
		{"position_m": position_error, "angle_degrees": rad_to_deg(angle_error)})
	var opposite_after := _opposite_arm_world_poses(slot)
	var opposite_position := 0.0
	var opposite_angle := 0.0
	for index: int in opposite_before:
		opposite_position = maxf(opposite_position, (opposite_before[index] as Transform3D).origin.distance_to((opposite_after[index] as Transform3D).origin))
		opposite_angle = maxf(opposite_angle, _angle((opposite_before[index] as Transform3D).basis, (opposite_after[index] as Transform3D).basis))
	_check(opposite_position <= 0.00005 and opposite_angle <= deg_to_rad(0.025), id + "_opposite_arm_world_fixed",
		{"maximum_position_m": opposite_position, "maximum_angle_degrees": rad_to_deg(opposite_angle)})

func _profiles() -> Dictionary:
	return {"shoulder": rig.shoulder_motion_profile.call("as_dictionary"), "wrist": rig.wrist_motion_profile.call("as_dictionary")}

func _bone_world(name: String) -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(name))

func _bone_names() -> Array[StringName]:
	var result: Array[StringName] = []
	for index: int in skeleton.get_bone_count(): result.append(StringName(skeleton.get_bone_name(index)))
	return result

func _rest_poses() -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for index: int in skeleton.get_bone_count(): result.append(skeleton.get_bone_rest(index))
	return result

func _find_record(previous: Dictionary, id: String) -> Dictionary:
	for record: Dictionary in previous.get("records", []):
		if record.get("id", "") == id: return record
	return {}

func _array_error(a: Variant, b: Variant) -> float:
	if a.size() != b.size(): return INF
	var maximum := 0.0
	for index: int in a.size(): maximum = maxf(maximum, absf(float(a[index]) - float(b[index])))
	return maximum

func _maximum(values: PackedFloat64Array) -> float:
	var result := -INF
	for value: float in values: result = maxf(result, value)
	return result

func _angle(a: Basis, b: Basis) -> float:
	var relative := (a.orthonormalized().get_rotation_quaternion().inverse() * b.orthonormalized().get_rotation_quaternion()).normalized()
	return 2.0 * atan2(Vector3(relative.x, relative.y, relative.z).length(), absf(relative.w))

func _digest(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(value))
	return context.finish().hex_encode()

func _read_binary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var value: Variant = file.get_var(false)
	file.close()
	return value if value is Dictionary else {}

func _check(passed: bool, label: String, detail: Variant = null) -> void:
	checks.append({"passed": passed, "label": label, "detail": detail})

func _checks_passed() -> bool:
	for check: Dictionary in checks:
		if not bool(check.passed): return false
	return true

func _finish() -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)
	var report := {"revision": FIXTURE_REVISION, "passed": _checks_passed(), "native_requested": native_enabled,
		"cached_storage_readback": cached_storage,
		"forearm_clearance_enabled": clearance_enabled, "commit_enabled": commit_enabled,
		"engine": Engine.get_version_info(), "processor_count": OS.get_processor_count(),
		"fixture_sha256": _digest(fixture), "fixture_source": fixture_path if not fixture_path.is_empty() else "fresh_actual_Idle",
		"scope": "Actual Josie allocator requests from identical Idle. Declared mathematical acquired Hand/prop binding; no finger acquisition, library, Save/F, skin or external scene collision certification. Clearance and live commit are explicit flags; compare only matching physical policies.",
		"checks": checks, "records": records}
	for entry: Dictionary in [{"name": "fixture.bin", "data": fixture}, {"name": "results.bin", "data": report}]:
		var file := FileAccess.open(output_dir.path_join(entry.name), FileAccess.WRITE)
		if file == null:
			push_error("Cannot write benchmark output " + entry.name)
			quit(1)
			return
		file.store_var(entry.data, false)
		file.close()
	var json := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	if json == null:
		push_error("Cannot write benchmark JSON output")
		quit(1)
		return
	json.store_string(JSON.stringify(_json_value(report), "\t"))
	json.close()
	print("MOTION_NATIVE_BENCH_DONE passed=%s cases=%d output=%s" % [report.passed, records.size(), output_dir])
	quit(0 if report.passed else 1)

func _json_value(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[String(key)] = _json_value(value[key])
		return result
	if value is Array or value is PackedFloat64Array or value is PackedFloat32Array or value is PackedInt32Array or value is PackedStringArray or value is PackedVector3Array:
		var result: Array = []
		for item: Variant in value: result.append(_json_value(item))
		return result
	if value is Vector3: return [value.x, value.y, value.z]
	if value is Quaternion: return [value.x, value.y, value.z, value.w]
	if value is Basis: return {"x": _json_value(value.x), "y": _json_value(value.y), "z": _json_value(value.z)}
	if value is Transform3D: return {"origin": _json_value(value.origin), "basis": _json_value(value.basis)}
	if value is StringName: return String(value)
	return value
