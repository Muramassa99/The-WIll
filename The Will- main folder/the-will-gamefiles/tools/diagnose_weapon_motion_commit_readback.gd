extends "res://tools/verify_combat_weapon_motion_rig.gd"

## Reuse the imported-rig fixture; retain acquisition bindings across commands.
## This diagnostic distinguishes evaluated legality from committed/readback
## legality. It does not load, modify or certify a player's saved weapon.
const Adapter = preload("res://runtime/player/combat_weapon_motion_rig_adapter.gd")
const Allocator = preload("res://core/resolvers/combat_weapon_motion_allocator.gd")
var readback_samples: Array[Dictionary] = []

func _initialize() -> void:
	output_dir = "C:/WORKSPACE/godot_runs/weapon_motion_allocator_20261030/commit_readback"
	super._initialize()

func _run() -> void:
	actor_parent = Node3D.new()
	root.add_child(actor_parent)
	rig = RigScene.instantiate() as PlayerHumanoidRig
	actor_parent.add_child(rig)
	await process_frame
	await process_frame
	rig.set_authoring_preview_mode_enabled(true)
	rig.reset_authoring_preview_baseline_pose()
	rig.set_process(false)
	rig.set_physics_process(false)
	for tree: Node in rig.find_children("*", "AnimationTree", true, false):
		(tree as AnimationTree).active = false
	skeleton = rig.skeleton
	_check(skeleton != null and rig.has_method("allocate_authoring_weapon_motion"), "allocator_rig_api_available")
	if skeleton == null or not rig.has_method("allocate_authoring_weapon_motion"):
		_finish()
		return
	for side: String in ["R", "L"]:
		_seed_bent_neutral_wrist(side)
	base_poses = _poses()
	_exercise_support_metric()
	for side: String in ["R", "L"]:
		_run_sequence(side, false)
		_run_sequence(side, true)
	_exercise_failed_commit_rollback()
	_finish()

func _exercise_support_metric() -> void:
	_restore()
	actor_parent.transform = Transform3D.IDENTITY
	var prop := Node3D.new()
	root.add_child(prop)
	prop.global_transform = _hand_world("R") * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.0))
	var bindings := {&"hand_right": prop.global_transform.affine_inverse() * _hand_world("R"),
		&"hand_left": prop.global_transform.affine_inverse() * _hand_world("L")}
	var adapter := Adapter.new()
	var initial: Dictionary = adapter.allocate(rig, _retained_request("R", "L", true, prop,
		prop.global_transform, bindings))
	_check(initial.get("status", "") in ["ACCEPTED", "SCALED"], "support_metric_fixture_valid", _compact_result(initial))
	if adapter.arms.size() < 2:
		prop.queue_free()
		return
	var initial_evaluation: Dictionary = adapter._evaluate(adapter.q)
	var actual: Transform3D = initial_evaluation.payload.hand_frames[&"hand_left"]
	# An offset along one coordinate and the same-length diagonal must use the
	# same physical allowance. Test safely inside/outside, not at float32 noise.
	for kind: String in ["position", "orientation"]:
		for ratio: float in [0.8, 1.2]:
			for direction: Vector3 in [Vector3.RIGHT, Vector3.ONE.normalized()]:
				var required := actual
				if kind == "position":
					required.origin += direction * float(adapter.policy.position_tolerance) * ratio
				else:
					required.basis = Basis(direction, float(adapter.policy.orientation_tolerance) * ratio) * actual.basis
				var hand_in_weapon := prop.global_transform.affine_inverse() * required
				adapter.arms[1]["hand_in_weapon"] = hand_in_weapon
				adapter.arms[1]["hand_to_weapon"] = hand_in_weapon.affine_inverse()
				var evaluated: Dictionary = adapter._evaluate(adapter.q)
				var legal := Allocator._evaluation_valid(evaluated) and Allocator._legal(adapter.q, evaluated, adapter.lower, adapter.upper)
				var label := "support_metric_%s_%s_%s" % [kind, "inside" if ratio < 1.0 else "outside", "axis" if direction == Vector3.RIGHT else "diagonal"]
				_check(legal == (ratio < 1.0), label, {"legal": legal, "ratio": ratio})
				readback_samples.append({"case": label, "evaluation": _inspect_evaluation(adapter, adapter.q, evaluated)})
	prop.queue_free()

func _exercise_failed_commit_rollback() -> void:
	_restore()
	actor_parent.transform = Transform3D.IDENTITY
	var prop := Node3D.new()
	root.add_child(prop)
	prop.global_transform = _hand_world("R") * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.0))
	var bindings := {&"hand_right": prop.global_transform.affine_inverse() * _hand_world("R"),
		&"hand_left": prop.global_transform.affine_inverse() * _hand_world("L")}
	var axis := prop.global_basis.y.normalized()
	var first: Dictionary = rig.allocate_authoring_weapon_motion(_retained_request("R", "L", true, prop,
		_orbit(prop.global_transform, Vector3.ZERO, axis, deg_to_rad(0.3)), bindings))
	var first_accepted: bool = first.get("status", "") in ["ACCEPTED", "SCALED"] and rig.commit_authoring_weapon_motion(first)
	_check(first_accepted, "rollback_fixture_previous_authority_committed", _compact_result(first))
	if not first_accepted:
		prop.queue_free()
		return
	var trial: Dictionary = rig.allocate_authoring_weapon_motion(_retained_request("R", "L", true, prop,
		_orbit(prop.global_transform, Vector3.ZERO, axis, deg_to_rad(0.3)), bindings))
	_check(trial.get("status", "") in ["ACCEPTED", "SCALED"], "rollback_fixture_next_trial_valid", _compact_result(trial))
	if trial.get("status", "") not in ["ACCEPTED", "SCALED"]:
		prop.queue_free()
		return
	var rotations_before := _rotation_bytes()
	var weapon_before := var_to_bytes(prop.global_transform)
	var wrist_before := var_to_bytes(rig.get("_wrist_motion_states"))
	var failures_before := var_to_bytes(rig.get("_wrist_motion_failures"))
	var authority_before := var_to_bytes(rig.get_authoring_weapon_motion_state())
	# Force an invalid stored result after numerical allocation. This tests the
	# transaction's readback guard, not rejection during candidate generation.
	var support_hand := skeleton.find_bone("CC_Base_L_Hand")
	var corrupted: Transform3D = trial.accepted_payload.local_poses[support_hand]
	corrupted.basis = Basis(Vector3.UP, deg_to_rad(0.5)) * corrupted.basis
	trial.accepted_payload.local_poses[support_hand] = corrupted
	var committed := rig.commit_authoring_weapon_motion(trial)
	_check(not committed, "invalid_commit_rejected", _compact_result(trial))
	_check(_rotation_bytes() == rotations_before, "invalid_commit_restores_exact_bone_rotations")
	_check(var_to_bytes(prop.global_transform) == weapon_before, "invalid_commit_restores_weapon")
	_check(var_to_bytes(rig.get("_wrist_motion_states")) == wrist_before, "invalid_commit_restores_wrist_states")
	_check(var_to_bytes(rig.get("_wrist_motion_failures")) == failures_before, "invalid_commit_restores_wrist_failures")
	_check(rig.has_authoring_weapon_motion_authority() and var_to_bytes(rig.get_authoring_weapon_motion_state()) == authority_before,
		"invalid_commit_preserves_previous_authority")
	var reversal: Dictionary = rig.allocate_authoring_weapon_motion(_retained_request("R", "L", true, prop,
		_orbit(prop.global_transform, Vector3.ZERO, axis, deg_to_rad(-0.3)), bindings))
	var reversal_accepted: bool = reversal.get("status", "") in ["ACCEPTED", "SCALED"] and rig.commit_authoring_weapon_motion(reversal)
	_check(reversal_accepted, "valid_reversal_after_failed_commit", _compact_result(reversal))
	readback_samples.append({"case": "forced_invalid_commit", "commit": _compact_result(trial), "reversal": _compact_result(reversal)})
	prop.queue_free()

func _rotation_bytes() -> PackedByteArray:
	var rotations: Array[Quaternion] = []
	for index: int in skeleton.get_bone_count():
		rotations.append(skeleton.get_bone_pose_rotation(index))
	return var_to_bytes(rotations)

func _run_sequence(side: String, two_hand: bool) -> void:
	_restore()
	actor_parent.transform = Transform3D.IDENTITY
	var prop := Node3D.new()
	root.add_child(prop)
	prop.global_transform = _hand_world(side) * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.0))
	var opposite := "L" if side == "R" else "R"
	var bindings := {_slot(side): prop.global_transform.affine_inverse() * _hand_world(side)}
	if two_hand:
		bindings[_slot(opposite)] = prop.global_transform.affine_inverse() * _hand_world(opposite)
	var initial_contact := prop.global_position
	var axis := prop.global_basis.y.normalized()
	var label := side + ("_two_hand" if two_hand else "_one_hand")
	var step := 0
	for angle: float in [0.5, 0.5, 0.5, -0.5, -0.5, -0.5]:
		step += 1
		var weapon_before: Transform3D = prop.global_transform
		var target := _orbit(prop.global_transform, Vector3.ZERO, axis, deg_to_rad(angle))
		var motion_request := _retained_request(side, opposite, two_hand, prop, target, bindings)
		# Same adapter used by the public rig API, kept here so even a rejected
		# initial state can be inspected without adding production instrumentation.
		var adapter := Adapter.new()
		var trial: Dictionary = adapter.allocate(rig, motion_request)
		var record := {"case": label, "step": step, "delta_degrees": angle,
			"trial": _compact_result(trial), "initial": _inspect(adapter)}
		var accepted: bool = trial.get("status", "") in ["ACCEPTED", "SCALED"]
		_check(accepted, "%s_step_%d_accepted" % [label, step], _compact_result(trial))
		if accepted:
			var predicted: Dictionary = adapter._evaluate(trial.accepted_q)
			record["predicted"] = _inspect_evaluation(adapter, trial.accepted_q, predicted)
			var committed := rig.commit_authoring_weapon_motion(trial)
			record["after_commit_result"] = _compact_result(trial)
			_check(committed, "%s_step_%d_committed" % [label, step], _compact_result(trial))
			record["committed"] = committed
			if committed:
				var actual_delta: Vector3 = Adapter._rotation_error(weapon_before.basis, prop.global_basis)
				var actual_angle_degrees := rad_to_deg(actual_delta.length())
				var signed_progress_degrees := rad_to_deg(actual_delta.dot(axis))
				record["actual_rotation_degrees"] = actual_angle_degrees
				record["signed_axis_progress_degrees"] = signed_progress_degrees
				record["grip_step_displacement_m"] = prop.global_position.distance_to(weapon_before.origin)
				record["grip_total_displacement_m"] = prop.global_position.distance_to(initial_contact)
				# A scaled target inside the orientation tolerance can otherwise
				# report acceptance without moving at all. It is not responsiveness.
				_check(actual_angle_degrees > 0.001, "%s_step_%d_actual_motion" % [label, step],
					{"actual_rotation_degrees": actual_angle_degrees, "requested_degrees": angle})
				_check(signed_progress_degrees * signf(angle) > 0.001, "%s_step_%d_requested_direction" % [label, step],
					{"signed_axis_progress_degrees": signed_progress_degrees, "requested_degrees": angle})
				record["primary_contact"] = _transform_error(_hand_world(side), prop.global_transform * bindings[_slot(side)])
				_check(_pose_error(_hand_world(side), prop.global_transform * bindings[_slot(side)]), "%s_step_%d_primary_contact" % [label, step], record.primary_contact)
				if two_hand:
					record["support_contact"] = _transform_error(_hand_world(opposite), prop.global_transform * bindings[_slot(opposite)])
					_check(_pose_error(_hand_world(opposite), prop.global_transform * bindings[_slot(opposite)]), "%s_step_%d_support_contact" % [label, step], record.support_contact)
				var readback := Adapter.new()
				var hold: Dictionary = readback.allocate(rig, _retained_request(side, opposite, two_hand,
					prop, prop.global_transform, bindings))
				record["readback"] = _inspect(readback)
				record["readback_hold"] = _compact_result(hold)
				record["bone_write_differences"] = _bone_differences(predicted.payload.local_poses, _poses())
				_check(hold.get("status", "") in ["ACCEPTED", "SCALED"],
					"%s_step_%d_committed_pose_still_legal" % [label, step], _compact_result(hold))
		readback_samples.append(record)
	prop.queue_free()

func _retained_request(side: String, opposite: String, two_hand: bool, prop: Node3D,
		target: Transform3D, bindings: Dictionary) -> Dictionary:
	var result := _request(side, prop, target, "tip")
	result["commit"] = false
	result["hand_in_weapon_by_slot"] = bindings
	if two_hand: result["support_slot"] = _slot(opposite)
	return result

func _inspect(adapter: CombatWeaponMotionRigAdapter) -> Dictionary:
	if adapter.arms.is_empty(): return {"built_arm_count": 0}
	return _inspect_evaluation(adapter, adapter.q, adapter._evaluate(adapter.q))

func _inspect_evaluation(adapter: CombatWeaponMotionRigAdapter, values: PackedFloat64Array, evaluation: Dictionary) -> Dictionary:
	var constraints := Allocator._constraints(evaluation)
	var reasons := PackedStringArray(evaluation.get("constraint_reasons", []))
	var rows: Array[Dictionary] = []
	for i: int in constraints.size():
		var reason: String = reasons[i] if i < reasons.size() else "SUPPORT_EQUALITY_%d" % (i - reasons.size())
		rows.append({"index": i, "reason": reason, "value": constraints[i],
			"violated": constraints[i] > Allocator.CONSTRAINT_EPSILON})
	var bounds: Array[Dictionary] = []
	for i: int in values.size():
		bounds.append({"index": i, "group": adapter.groups[i], "value": values[i],
			"lower": adapter.lower[i], "upper": adapter.upper[i],
			"violated": values[i] < adapter.lower[i] - Allocator.CONSTRAINT_EPSILON or values[i] > adapter.upper[i] + Allocator.CONSTRAINT_EPSILON})
	return {"valid_evaluation": Allocator._evaluation_valid(evaluation),
		"legal": Allocator._legal(values, evaluation, adapter.lower, adapter.upper),
		"evaluation_reason": evaluation.get("reason", ""), "constraints": rows, "bounds": bounds,
		"wrist_states_by_slot": evaluation.get("payload", {}).get("wrist_states_by_slot", {})}

func _compact_result(result: Dictionary) -> Dictionary:
	var compact := {}
	for key: String in ["valid", "status", "reason", "task_scale", "active_limits", "contributing_joint_groups", "iterations", "pivot_error", "orientation_error", "initial_diagnostics", "commit_readback_valid", "commit_diagnostics", "storage_validation_failures", "storage_validation_last_failure", "search_failures", "timings"]:
		if result.has(key): compact[key] = result[key]
	return compact

func _bone_differences(predicted: Array, actual: Array) -> Array[Dictionary]:
	var differences: Array[Dictionary] = []
	for i: int in mini(predicted.size(), actual.size()):
		var error: Dictionary = _transform_error(predicted[i], actual[i])
		if float(error.position_error_m) > 0.0 or float(error.orientation_error_degrees) > 0.000001:
			error["bone"] = skeleton.get_bone_name(i)
			differences.append(error)
	return differences

func _finish() -> void:
	var passed := true
	for check: Dictionary in checks: passed = passed and bool(check.passed)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir.path_join("readback_report.json"), FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "samples": readback_samples,
		"scope": "Imported rig fixture, repeated fresh allocation and commit readback with fixed acquired bindings. No saved library or real grip acquisition certification."}, "\t"))
	file.close()
	print("WEAPON_MOTION_COMMIT_READBACK passed=%s checks=%d output=%s" % [passed, checks.size(), output_dir])
	quit(0 if passed else 1)
