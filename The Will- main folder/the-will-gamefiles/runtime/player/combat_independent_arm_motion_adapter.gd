extends "res://runtime/player/combat_weapon_motion_rig_adapter.gd"
class_name CombatIndependentArmMotionAdapter

const MAX_ELBOW_ORBIT_STEPS := 64
const ELBOW_BOUNDARY_SEARCH_STEPS := 7

## Same skeletal machine as weapon editing, with a different controlled frame.
## The allocator's historical `weapon_frame`/`accepted_weapon` keys mean the
## world Hand frame for a free-hand task or world Elbow origin for a swivel.
## No weapon object, acquired-grip change, finger search or shared ancestor edit.

func move_hand(owner: Node3D, slot: StringName, target_world: Transform3D) -> Dictionary:
	var skel: Skeleton3D = owner.get("skeleton") as Skeleton3D
	var prefix := "CC_Base_L_" if slot == SLOT_LEFT else "CC_Base_R_"
	var index: int = skel.find_bone(prefix + "Hand") if skel != null else -1
	if index < 0:
		return _failure("independent_hand_frame_missing", "INVALID_PROFILE")
	var current: Transform3D = skel.global_transform * skel.get_bone_global_pose(index)
	return allocate(owner, {"mode": "pose", "primary_slot": slot,
		"previous_weapon": current, "target_weapon": target_world,
		"contact_local": Vector3.ZERO, "hand_in_weapon_by_slot": {slot: Transform3D.IDENTITY}})

func move_elbow(owner: Node3D, slot: StringName, target_world: Vector3, retained_hand_world: Variant = null) -> Dictionary:
	var skel: Skeleton3D = owner.get("skeleton") as Skeleton3D
	var prefix := "CC_Base_L_" if slot == SLOT_LEFT else "CC_Base_R_"
	var elbow: int = skel.find_bone(prefix + "Forearm") if skel != null else -1
	var hand: int = skel.find_bone(prefix + "Hand") if skel != null else -1
	var shoulder: int = skel.find_bone(prefix + "Upperarm") if skel != null else -1
	if mini(mini(elbow, hand), shoulder) < 0:
		return _failure("independent_elbow_frame_missing", "INVALID_PROFILE")
	var current: Vector3 = (skel.global_transform * skel.get_bone_global_pose(elbow)).origin
	var held_hand: Transform3D = skel.global_transform * skel.get_bone_global_pose(hand)
	if retained_hand_world is Transform3D:
		held_hand = retained_hand_world
	var pivot: Vector3 = (skel.global_transform * skel.get_bone_global_pose(shoulder)).origin
	var axis: Vector3 = (held_hand.origin - pivot).normalized()
	var from_radial: Vector3 = current - pivot - axis * (current - pivot).dot(axis)
	var to_radial: Vector3 = target_world - pivot - axis * (target_world - pivot).dot(axis)
	var sweep: float = atan2(axis.dot(from_radial.cross(to_radial)), from_radial.dot(to_radial))
	return _allocate_elbow_orbit(owner, {"mode": "position", "primary_slot": slot,
		"previous_weapon": Transform3D(Basis.IDENTITY, current),
		"target_weapon": Transform3D(Basis.IDENTITY, target_world),
		"fixed_hand_world": held_hand, "contact_local": Vector3.ZERO,
		"task_path": {"kind": "orbit", "center": pivot, "axis": axis, "angle_radians": sweep},
		"hand_in_weapon_by_slot": {slot: Transform3D.IDENTITY}})

## Elbow swivel has one known geometric path: rotate the two arm segments
## together around Shoulder -> retained Hand. Solve that path directly instead
## of asking a redundant QP to discover it through six tight Hand constraints.
## Candidate construction never accepts anatomy: shared FK, the original
## allowance, retained contact and stored-bone readback still decide acceptance.
func _allocate_elbow_orbit(owner: Node3D, motion_request: Dictionary) -> Dictionary:
	allocation_start_usec = Time.get_ticks_usec()
	var initialized := _initialize(owner, motion_request)
	if not initialized.get("valid", false):
		return initialized
	var input := _allocator_input()
	var path_check := Allocator._validate_task_path(input, "position", previous_weapon, request.target_weapon, policy)
	if not path_check.get("valid", false):
		return _failure(path_check.reason, "INVALID_PROFILE")
	var initial: Dictionary = _evaluate(q)
	var initial_check := Allocator.validate_with_start_allowance(input, initial, policy, start_allowance)
	if not initial_check.get("valid", false):
		return initial_check
	var initial_storage := _validate_candidate(Allocator.apply_start_allowance(initial, start_allowance))
	if not initial_storage.get("valid", false):
		return initial_storage
	var arm: Dictionary = arms[0]
	var upper_world: Transform3D = skeleton_world * skeleton.get_bone_global_pose(arm.indices[1])
	var forearm_world: Transform3D = skeleton_world * skeleton.get_bone_global_pose(arm.indices[2])
	var parent_skeleton: Transform3D = skeleton.get_bone_global_pose(arm.indices[0])
	var base := {"upper_world": upper_world, "forearm_world": forearm_world,
		"parent_skeleton": parent_skeleton, "world_to_skeleton": skeleton_world.affine_inverse(),
		"held_hand_skeleton": skeleton_world.affine_inverse() * (request.fixed_hand_world as Transform3D),
		"path": path_check.path,
		"wrist_state": {"rho": q[arm.wrist_q], "beta": q[arm.wrist_q + 1], "gamma": q[arm.wrist_q + 2]}}
	var sweep: float = base.path.angle_radians
	var step_angle := minf(deg_to_rad(2.0), float(policy.max_rotation_step) * 0.25)
	var count := maxi(1, int(ceil(absf(sweep) / step_angle)))
	var accepted_fraction := 0.0
	var accepted_q := q.duplicate()
	var accepted_evaluation := initial
	var attempts := 0
	var boundary: Dictionary = {}
	if absf(sweep) <= EPSILON:
		accepted_fraction = 1.0
	else:
		for step: int in mini(count, MAX_ELBOW_ORBIT_STEPS):
			var fraction := float(step + 1) / float(count)
			var candidate := _elbow_orbit_candidate(fraction, base)
			attempts += 1
			if candidate.get("valid", false):
				var changed: bool = candidate.q != accepted_q
				accepted_fraction = fraction
				accepted_q = candidate.q
				accepted_evaluation = candidate.evaluation
				if changed:
					_advance_accepted_checkpoint(accepted_evaluation)
				continue
			boundary = candidate
			var low := accepted_fraction
			var high := fraction
			var old_fraction := accepted_fraction
			var old_q := accepted_q.duplicate()
			for _search: int in ELBOW_BOUNDARY_SEARCH_STEPS:
				var middle := (low + high) * 0.5
				var smaller := _elbow_orbit_candidate(middle, base)
				attempts += 1
				if smaller.get("valid", false):
					low = middle
					accepted_q = smaller.q
					accepted_evaluation = smaller.evaluation
				else:
					high = middle
			accepted_fraction = low
			if low > old_fraction + EPSILON and accepted_q != old_q:
				_advance_accepted_checkpoint(accepted_evaluation)
			break
	var meaningful_request := previous_weapon.origin.distance_to((request.target_weapon as Transform3D).origin) > float(policy.position_tolerance)
	if meaningful_request and accepted_q == q:
		accepted_fraction = 0.0
	var complete := accepted_fraction >= 1.0 - EPSILON
	var valid := accepted_fraction > EPSILON
	var reason := ""
	if not complete:
		reason = String(boundary.get("reason", "independent_elbow_orbit_step_budget"))
	var result := {"valid": valid, "status": "ACCEPTED" if complete else ("SCALED" if valid else "SEARCH_EXHAUSTED"),
		"reason": reason, "accepted_q": accepted_q, "accepted_weapon": accepted_evaluation.weapon_frame,
		"accepted_payload": accepted_evaluation.payload, "task_scale": accepted_fraction,
		"iterations": attempts, "revision": Allocator.REVISION, "motion_adapter": self,
		"initial_warning": initial_check.get("initial_warning", {}),
		"allocation_method": "fixed_hand_analytic_elbow_orbit", "position_constrained": true, "orientation_constrained": false}
	if not boundary.is_empty():
		result["orbit_boundary"] = {"reason": boundary.get("reason", ""), "diagnostics": boundary.get("diagnostics", {})}
	var expected := Allocator._target_at(previous_weapon, request.target_weapon, Vector3.ZERO,
		"position", accepted_fraction, Vector3.ZERO, base.path)
	result["pivot_error"] = (accepted_evaluation.weapon_frame as Transform3D).origin.distance_to(expected.origin)
	result["orientation_error"] = 0.0
	result["remaining_task_error"] = {"position": (accepted_evaluation.weapon_frame as Transform3D).origin.distance_to((request.target_weapon as Transform3D).origin), "angle": 0.0}
	result["contributing_joint_groups"] = Allocator._contributing_groups(q, accepted_q, PackedStringArray(groups))
	result["pose_warning"] = Allocator._pose_warning(accepted_q, accepted_evaluation, lower, upper, PackedStringArray(groups))
	result["active_limits"] = Allocator._active_limits(accepted_q, lower, upper, accepted_evaluation)
	if valid and bool(request.get("commit", true)) and not commit_result(result):
		return result
	result["accepted_pose"] = _pose_packet(result.accepted_payload.local_poses)
	result["accepted_weapon_origin_id"] = &"world"
	result["wrist_states_by_slot"] = result.accepted_payload.wrist_states_by_slot.duplicate(true)
	result["shoulder_states_by_slot"] = result.accepted_payload.shoulder_states_by_slot.duplicate(true)
	result["origin_id"] = Origin.ORIGIN_RL_BONE_ROOT
	result["coordinate_contract"] = "world_elbow_task_and_retained_hand; parent_bone_local_pose; ancestry_to_RL_BoneRoot"
	result["timings"] = _timing_result()
	result["storage_validation_failures"] = storage_validation_failures.duplicate()
	result["storage_validation_last_failure"] = storage_validation_last_failure.duplicate(true)
	return result

func _elbow_orbit_candidate(fraction: float, base: Dictionary) -> Dictionary:
	var arm: Dictionary = arms[0]
	var path: Dictionary = base.path
	var turn := Basis(path.axis, float(path.angle_radians) * fraction)
	var upper_world: Transform3D = base.upper_world
	var forearm_world: Transform3D = base.forearm_world
	upper_world.basis = turn * upper_world.basis
	forearm_world.basis = turn * forearm_world.basis
	forearm_world.origin = (path.center as Vector3) + turn * (forearm_world.origin - (path.center as Vector3))
	var upper_skeleton: Transform3D = (base.world_to_skeleton as Transform3D) * upper_world
	var forearm_skeleton: Transform3D = (base.world_to_skeleton as Transform3D) * forearm_world
	var desired_local: Transform3D = (base.parent_skeleton as Transform3D).affine_inverse() * upper_skeleton
	var vector := _rotation_error((local_poses[arm.indices[1]] as Transform3D).basis, desired_local.basis)
	var shoulder_axes: Basis = arm.shoulder_axes
	var values := q.duplicate()
	values[arm.shoulder_q] = vector.dot(shoulder_axes.x)
	values[arm.shoulder_q + 1] = vector.dot(shoulder_axes.z)
	values[arm.shoulder_q + 2] = vector.dot(shoulder_axes.y)
	var wrist: Dictionary = Wrist.measure_state(forearm_skeleton, base.held_hand_skeleton,
		arm.wrist_calibration, arm.wrist_profile, base.wrist_state, values[arm.elbow_q], float(arm.full_flexion))
	if not wrist.get("valid", false):
		return {"valid": false, "reason": wrist.get("reason", "independent_elbow_wrist_measurement_failed"), "diagnostics": wrist}
	values[arm.wrist_q] = float(wrist.state.rho)
	values[arm.wrist_q + 1] = float(wrist.state.beta)
	values[arm.wrist_q + 2] = float(wrist.state.gamma)
	var evaluation := _evaluate(values)
	var permitted := Allocator.apply_start_allowance(evaluation, start_allowance)
	if not Allocator._evaluation_valid(permitted) or not Allocator._legal(values, permitted, start_allowance.lower, start_allowance.upper):
		var details := Allocator._initial_diagnostics(values, permitted, start_allowance.lower, start_allowance.upper, PackedStringArray(groups))
		var reason := "independent_elbow_anatomical_boundary"
		if not details.constraints.is_empty():
			reason = String(details.constraints[0].name)
		return {"valid": false, "reason": reason, "diagnostics": details}
	# Full FK must reproduce the orbit and the retained Hand; a decomposition
	# that only works under an assumed unit/uniform ancestor scale is not enough.
	var expected := Allocator._target_at(previous_weapon, request.target_weapon, Vector3.ZERO,
		"position", fraction, Vector3.ZERO, path)
	var error: float = (evaluation.weapon_frame as Transform3D).origin.distance_to(expected.origin)
	if error > float(policy.position_tolerance):
		return {"valid": false, "reason": "independent_elbow_orbit_fk_mismatch", "diagnostics": {"position_error_m": error}}
	var stored := _validate_candidate(permitted)
	if not stored.get("valid", false):
		return {"valid": false, "reason": stored.get("reason", "independent_elbow_storage_rejected"), "diagnostics": stored}
	return {"valid": true, "q": values, "evaluation": evaluation}

func _requires_weapon_node() -> bool:
	return false

func _controlled_frame_world() -> Transform3D:
	var arm: Dictionary = arms[0]
	if request.has("fixed_hand_world"):
		return Transform3D(Basis.IDENTITY, (skeleton.global_transform * skeleton.get_bone_global_pose(arm.indices[2])).origin)
	return skeleton.global_transform * skeleton.get_bone_global_pose(arm.indices[3])

func _write_controlled_frame_world(_frame: Transform3D) -> void:
	# The accepted bones already own the control point. Never move a prop or an
	# attachment to manufacture agreement with the requested task.
	pass

func _evaluate_kinematics(values: PackedFloat64Array) -> Dictionary:
	var result: Dictionary = super._evaluate_kinematics(values)
	if not result.get("valid", false) or arms.is_empty():
		return result
	if not request.has("fixed_hand_world"):
		return result
	var arm: Dictionary = arms[0]
	var globals: Array = result.payload.globals
	var controlled := Transform3D(Basis.IDENTITY, (skeleton_world * (globals[arm.indices[2]] as Transform3D)).origin)
	result.weapon_frame = controlled
	result.weapon_transform = controlled
	# Elbow is the task; Hand is a retained world constraint, including its
	# orientation. A final upperarm clamp would break this relationship.
	var hand: Transform3D = result.payload.hand_frames[arm.slot]
	var held: Transform3D = request.fixed_hand_world
	_append_hand_pin(result, hand.origin - held.origin, _rotation_error(held.basis, hand.basis))
	return result

func _append_hand_pin(result: Dictionary, position_error: Vector3, rotation_error: Vector3) -> void:
	var position := position_error / float(policy.position_tolerance)
	var angle := rotation_error / float(policy.orientation_tolerance)
	var values: PackedFloat64Array = result.constraints
	var reasons: PackedStringArray = result.constraint_reasons
	var search: PackedFloat64Array = result.search_constraints
	var search_reasons: PackedStringArray = result.search_constraint_reasons
	var labels := ["CONTACT_DISTANCE:independent_hand", "CONTACT_ORIENTATION:independent_hand"]
	var residuals := [position, angle]
	for index: int in 2:
		var residual: Vector3 = residuals[index]
		var label: String = labels[index]
		result.squared_norm_residuals[values.size()] = residual
		values.append(residual.length_squared() - 1.0)
		reasons.append(label)
		for axis: int in 3:
			search.append(residual[axis] - 1.0 / sqrt(3.0))
			search.append(-residual[axis] - 1.0 / sqrt(3.0))
			search_reasons.append(label + ":search_positive:" + str(axis))
			search_reasons.append(label + ":search_negative:" + str(axis))
	result.constraints = values
	result.constraint_values = values
	result.constraint_reasons = reasons
	result.search_constraints = search
	result.search_constraint_reasons = search_reasons

func _validate_committed_pose(accepted_frame: Transform3D, _enforce_task_anchor: bool = true) -> Dictionary:
	var actual := _controlled_frame_world()
	var position_error: float = actual.origin.distance_to(accepted_frame.origin)
	var angle_error: float = 0.0 if request.has("fixed_hand_world") else _physical_angle(actual.basis, accepted_frame.basis)
	if position_error > float(policy.position_tolerance) or angle_error > float(policy.orientation_tolerance):
		return {"valid": false, "reason": "independent_task_storage_mismatch",
			"position_error_m": position_error, "angle_error_radians": angle_error}
	if request.has("fixed_hand_world"):
		var hand: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(arms[0].indices[3])
		var held: Transform3D = request.fixed_hand_world
		position_error = hand.origin.distance_to(held.origin)
		angle_error = _physical_angle(hand.basis, held.basis)
		if position_error > float(policy.position_tolerance) or angle_error > float(policy.orientation_tolerance):
			return {"valid": false, "reason": "independent_hand_pin_storage_mismatch",
				"position_error_m": position_error, "angle_error_radians": angle_error}
	var next_request := request.duplicate()
	next_request.erase("task_path")
	next_request.previous_weapon = _controlled_frame_world()
	next_request.target_weapon = next_request.previous_weapon
	next_request.commit = false
	var readback := CombatIndependentArmMotionAdapter.new()
	var initialized: Dictionary = readback._initialize(rig, next_request)
	if not initialized.get("valid", false):
		return initialized
	return Allocator.validate_with_start_allowance(readback._allocator_input(),
		readback._evaluate_kinematics(readback.q), readback.policy, start_allowance)

static func _physical_angle(actual: Basis, expected: Basis) -> float:
	var rotation: Quaternion = (actual.orthonormalized().get_rotation_quaternion().inverse() * expected.orthonormalized().get_rotation_quaternion()).normalized()
	return 2.0 * atan2(Vector3(rotation.x, rotation.y, rotation.z).length(), absf(rotation.w))
