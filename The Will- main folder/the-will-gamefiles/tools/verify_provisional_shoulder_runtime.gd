extends "res://tools/verify_josie_provisional_shoulder_poses.gd"

## Small live-profile integration check reusing reviewed pose construction.
## Actual imported/animated translations and scales are retained. A numerical
## rigid prop supplies contact; this is not a finger-grip or saved-skill test.
const Adapter = preload("res://runtime/player/combat_weapon_motion_rig_adapter.gd")
const Allocator = preload("res://core/resolvers/combat_weapon_motion_allocator.gd")
const Capture = preload("res://runtime/combat/combat_prepared_pose_capture.gd")

func _initialize() -> void:
	output_dir = "C:/WORKSPACE/godot_runs/provisional_shoulder_runtime"
	screenshots = false
	super._initialize()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)
	rig = RigScene.instantiate() as PlayerHumanoidRig
	root.add_child(rig)
	await process_frame
	await process_frame
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	for node: Node in rig.find_children("*", "AnimationTree", true, false): (node as AnimationTree).active = false
	for node: Node in rig.find_children("*", "AnimationPlayer", true, false): (node as AnimationPlayer).stop(true)
	for node: Node in rig.find_children("*", "SkeletonModifier3D", true, false): (node as SkeletonModifier3D).active = false
	skeleton = rig.skeleton
	_record_check(skeleton != null, "imported_skeleton_available")
	if skeleton == null:
		_finish()
		return
	baseline = _poses()
	_record_check(String(rig.shoulder_motion_profile.coverage_mode) == "continuous_provisional", "uses_enabled_live_profile")
	for side: String in ["R", "L"]:
		for spec: Vector2 in [Vector2(2.0, 0.0), Vector2(120.0, 45.0), Vector2(30.0, -90.0)]:
			_exercise_region(side, spec)
	_restore(baseline)
	_finish()

func _read_shoulder(side: String, calibration: Dictionary) -> Dictionary:
	return Shoulder.measure(skeleton.get_bone_global_pose(skeleton.find_bone(String(calibration.chest_bone_name))),
		skeleton.get_bone_global_pose(_bone(side, "Upperarm")), skeleton.get_bone_global_pose(_bone(side, "Forearm")),
		calibration, rig.shoulder_motion_profile.as_dictionary(), rig.get("_shoulder_motion_states").get(_slot(side), {}))

func _runtime_adapter(side: String, prop: Node3D) -> Adapter:
	var adapter := Adapter.new()
	var request := {"mode": "tip", "weapon": prop, "previous_weapon": prop.global_transform,
		"target_weapon": prop.global_transform, "contact_local": Vector3.ZERO, "primary_slot": _slot(side),
		"hand_in_weapon_by_slot": {_slot(side): Transform3D.IDENTITY}, "commit": false}
	var initialized: Dictionary = adapter._initialize(rig, request)
	_record_check(initialized.get("valid", false), side + "_adapter_initialization", initialized)
	return adapter if initialized.get("valid", false) else null

func _shoulder_constraints(evaluation: Dictionary, side: String) -> PackedFloat64Array:
	var result := PackedFloat64Array()
	if not evaluation.get("valid", false): return result
	var reasons: PackedStringArray = evaluation.constraint_reasons
	for index: int in reasons.size():
		if reasons[index] in ["JOINT_RANGE:shoulder_internal:" + String(_slot(side)), "JOINT_RANGE:shoulder_external:" + String(_slot(side))]:
			result.append(evaluation.constraints[index])
	return result

func _isolated_step(adapter: Adapter, internal_degrees: float) -> Dictionary:
	var arm: Dictionary = adapter.arms[0]
	var index: int = arm.shoulder_q + 2
	var target_q: PackedFloat64Array = adapter.q.duplicate()
	target_q[index] += deg_to_rad(internal_degrees) * float(arm.shoulder_calibration.internal_sign)
	var target: Dictionary = adapter._evaluate_kinematics(target_q)
	if not target.get("valid", false): return target
	var input: Dictionary = adapter._allocator_input().duplicate(true)
	input.lower = adapter.q.duplicate()
	input.upper = adapter.q.duplicate()
	input.lower[index] = adapter.lower[index]
	input.upper[index] = adapter.upper[index]
	input.target_weapon = target.weapon_frame
	var result: Dictionary = Allocator.solve(input, Callable(adapter, "_evaluate"), adapter.policy)
	result["motion_adapter"] = adapter
	return result

func _compact(result: Dictionary) -> Dictionary:
	var value := result.duplicate()
	for key: String in ["motion_adapter", "accepted_payload", "accepted_pose"]:
		value.erase(key)
	return value

func _exercise_region(side: String, spec: Vector2) -> void:
	_restore(baseline)
	for property: String in ["_wrist_motion_states", "_wrist_motion_failures", "_shoulder_motion_states"]:
		rig.get(property).clear()
	var label := "%s_e%d_p%d" % [side, spec.x, spec.y]
	var calibration: Dictionary = Calibration.build(skeleton, _slot(side))
	var seeded := _seed_centre(side, _direction(spec.x, spec.y, side), calibration)
	_record_check(seeded.get("valid", false), label + "_fixed_centre_seeded", seeded.get("reason", ""))
	if not seeded.get("valid", false): return
	var centre := _read_shoulder(side, calibration)
	_record_check(centre.get("valid", false) and centre.get("covered", false), label + "_covered_by_live_profile", centre)
	if not centre.get("valid", false) or not centre.get("covered", false): return
	var minimum: float = centre.minimum_radians
	var maximum: float = centre.maximum_radians
	# The entire captured constraint packet carries the same profile/provenance
	# through serialization. No player save or library is read or overwritten.
	var packet := Capture.capture_arm_constraints(rig, rig.global_transform)
	var roundtrip: Dictionary = bytes_to_var(var_to_bytes(packet))
	var saved_profile: Dictionary = roundtrip.get(_slot(side), {}).get("shoulder_profile", {})
	_record_check(saved_profile == rig.shoulder_motion_profile.as_dictionary(), label + "_captured_profile_survives_roundtrip")
	if not saved_profile.is_empty():
		var saved := Shoulder.sample_bounds(centre.direction_anatomical, calibration.side_sign, saved_profile, calibration.internal_sign)
		_record_check(saved.covered and absf(saved.minimum_radians - minimum) < 0.00001 and absf(saved.maximum_radians - maximum) < 0.00001,
			label + "_captured_playback_bounds_match_live")
	# Seed just inside the upper endpoint, then ask for two degrees outward.
	var posed := _set_h(side, calibration, maximum - deg_to_rad(0.1))
	_record_check(posed.get("valid", false), label + "_endpoint_pose_constructed")
	if not posed.get("valid", false): return
	var at_endpoint := _read_shoulder(side, calibration)
	var endpoint_shoulder_world := skeleton.global_transform * skeleton.get_bone_global_pose(_bone(side, "Upperarm")).origin
	var endpoint_elbow_world := skeleton.global_transform * skeleton.get_bone_global_pose(_bone(side, "Forearm")).origin
	rig.get("_shoulder_motion_states")[_slot(side)] = at_endpoint.state.duplicate()
	var prop := Node3D.new()
	root.add_child(prop)
	prop.global_transform = skeleton.global_transform * skeleton.get_bone_global_pose(_bone(side, "Hand"))
	var adapter := _runtime_adapter(side, prop)
	if adapter == null:
		prop.free()
		return
	var arm: Dictionary = adapter.arms[0]
	var index: int = arm.shoulder_q + 2
	# Independently verify the opposite endpoint also has a finite outward stop.
	var beyond_lower: PackedFloat64Array = adapter.q.duplicate()
	beyond_lower[index] += (minimum - deg_to_rad(1.0) - float(at_endpoint.state.h)) * float(calibration.internal_sign)
	var lower_rows := _shoulder_constraints(adapter._evaluate_kinematics(beyond_lower), side)
	_record_check(lower_rows.size() == 2 and maxf(lower_rows[0], lower_rows[1]) > deg_to_rad(0.5), label + "_external_endpoint_is_finite")
	var first := _isolated_step(adapter, 2.0)
	if first.get("valid", false):
		_record_check(adapter.commit_result(first), label + "_outward_partial_commit_readback", _compact(first))
	var first_pose := _read_shoulder(side, calibration)
	_record_check(float(first_pose.state.h) <= float(first_pose.maximum_radians) + 0.00001,
		label + "_outward_stops_at_internal_endpoint", first_pose)
	# New adapter simulates release/regrab; it must keep the same fixed bounds.
	var regrab := _runtime_adapter(side, prop)
	if regrab == null:
		prop.free()
		return
	var again := _isolated_step(regrab, 2.0)
	if again.get("valid", false):
		_record_check(regrab.commit_result(again), label + "_regrab_partial_commit_readback", _compact(again))
	var second_pose := _read_shoulder(side, calibration)
	# With actual animated offsets, axial material rotation can carry a tiny
	# shaft displacement. Compare bounds at the SAME observed direction, not
	# the centre's direction; regional bounds legitimately vary with direction.
	var repeated := Shoulder.sample_bounds(second_pose.direction_anatomical, calibration.side_sign, saved_profile, calibration.internal_sign)
	_record_check(float(second_pose.state.h) <= float(second_pose.maximum_radians) + 0.00001
		and repeated.covered and absf(second_pose.minimum_radians - repeated.minimum_radians) < 0.00001
		and absf(second_pose.maximum_radians - repeated.maximum_radians) < 0.00001,
		label + "_regrab_does_not_rebase_limits", second_pose)
	var current_shoulder := skeleton.global_transform * skeleton.get_bone_global_pose(_bone(side, "Upperarm")).origin
	var current_elbow := skeleton.global_transform * skeleton.get_bone_global_pose(_bone(side, "Forearm")).origin
	var direction_error: float = (at_endpoint.direction_anatomical as Vector3).angle_to(second_pose.direction_anatomical)
	_record_check(current_shoulder.distance_to(endpoint_shoulder_world) <= POSITION_EPSILON
		and current_elbow.distance_to(endpoint_elbow_world) <= POSITION_EPSILON and direction_error <= ANGLE_EPSILON,
		label + "_endpoint_motion_stays_within_existing_numerical_tolerance",
		{"shoulder_m": current_shoulder.distance_to(endpoint_shoulder_world), "elbow_m": current_elbow.distance_to(endpoint_elbow_world),
		"direction_degrees": rad_to_deg(direction_error)})
	var reverse := _runtime_adapter(side, prop)
	if reverse != null:
		var inward := _isolated_step(reverse, -2.0)
		_record_check(inward.get("valid", false) and inward.get("status", "") == "ACCEPTED", label + "_inward_reversal_is_accepted", _compact(inward))
		if inward.get("valid", false):
			_record_check(reverse.commit_result(inward), label + "_inward_commit_readback", _compact(inward))
			var final_pose := _read_shoulder(side, calibration)
			_record_check(float(final_pose.state.h) < float(second_pose.state.h) - deg_to_rad(1.5), label + "_inward_reversal_actually_moves")
	var offsets := true
	for bone: int in baseline.size():
		var current := skeleton.get_bone_pose(bone)
		offsets = offsets and current.origin.is_equal_approx(baseline[bone].origin) and current.basis.get_scale().is_equal_approx(baseline[bone].basis.get_scale())
	_record_check(offsets, label + "_actual_offsets_and_scale_preserved")
	rows.append({"id": label, "centre": centre, "first": _compact(first), "regrab": _compact(again)})
	prop.free()

func _finish() -> void:
	var passed := true
	for check: Dictionary in checks:
		passed = passed and bool(check.passed)
	var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"passed": passed, "checks": checks, "cases": rows,
			"scope": "Live-profile imported rig, retained actual offsets, rigid numerical contact, isolated shoulder endpoint/regrab/backoff and captured-profile serialization. No finger solve, player save, UI or full skill playback certification."}, "\t"))
		file.close()
	else:
		passed = false
		push_error("Cannot write provisional shoulder runtime report")
	print("PROVISIONAL_SHOULDER_RUNTIME passed=%s checks=%d" % [passed, checks.size()])
	quit(0 if passed else 1)

func _record_check(passed: bool, label: String, detail: Variant = null) -> void:
	checks.append({"passed": passed, "label": label, "detail": detail})
	if not passed:
		push_error(label + ": " + str(detail))
