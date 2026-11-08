extends RefCounted
class_name CombatWeaponMotionAllocator

## Pure constrained weapon task allocation. All transforms use input.origin_id;
## contact_local belongs to the weapon transform, never an implicit world zero.
## The runtime adapter owns calibrated FK, anatomy, collision and bone writes.
## evaluate(q) returns weapon_frame, constraints <= 0, and optional equalities
## with per-row equality_tolerances. It MUST NOT mutate the live skeleton.
## Optional squared_norm_residuals maps a constraint row to its Vector3 residual
## (row = residual.length_squared() - 1); its derivative uses the chain rule.
## Optional search_constraints supplies conservative QP guidance only. Initial,
## nonlinear, transition and final legality always use the physical constraints.
## Named anatomical excess already present at input is inherited for this one
## request only. New poses may correct it without first requiring a valid pose;
## they may never exceed that starting excess. Acquired contact stays strict.
## No persistent raw target: every request starts from the last accepted state.
## Tip commands orientation only; grip position follows the legal joint FK.
## Pommel commands only its WeaponRoot-local task_point_local position. If
## omitted, generic callers retain contact_local as their addressed point.
## Its orientation follows legal FK; acquired contact_local remains distinct.
## Optional trailing_tip_local is another WeaponRoot-local landmark. Weighted
## Pommel posture selection prefers keeping it near its previous actual world
## position; it adds no endpoint, angular, timing or contact constraint.
## Roll alone retains a world contact_anchor in the SAME origin_id as the
## weapon frames. Omitting it starts Roll at the previous contact position.
## Optional translation_reach_bound must conservatively cover the addressed
## point including its free orientation, in the SAME origin. The live adapter
## no longer supplies its old fixed-orientation wrist bound for Pommel.
## An explicit caller bound only prunes targets; it never replaces legality.
## Generic pose/position modes let independent arm tasks use the same mechanical
## solver. Historical weapon_frame keys then name a caller-owned task frame in
## input.origin_id; position addresses its origin, pose its full transform.
## Optional posture_spans normalizes preference travel only, never joint bounds.
## A position task may supply task_path={kind:"orbit", center, axis,
## angle_radians}; all path points remain on that caller-defined rigid orbit.
const MotionMath = preload("res://core/resolvers/combat_motion_math_backend.gd")
const PolicyDef = preload("res://core/defs/weapon_motion_policy_def.gd")
const REVISION := "weapon_motion_allocation_v1"
const NUMERIC_EPSILON := 1.0e-8
const CONSTRAINT_EPSILON := 1.0e-6
const PIVOT_EPSILON := 1.0e-10
const QP_ITERATIONS := 80
# Search effort only: never an anatomical limit or a new shoulder reference.
const MAX_SHOULDER_COVERAGE_CROSSING_ITERATIONS := 3
# A request can continue from a certified coverage-edge task checkpoint. This
# budget is deliberately separate from Newton trials and does not grant ROM.
const MAX_COVERAGE_HANDOFFS_PER_REQUEST := 2

static func solve(input: Dictionary, evaluate: Callable, overrides: Dictionary = {}) -> Dictionary:
	var policy: Dictionary = PolicyDef.new().as_dictionary()
	policy.merge(overrides, true)
	var q := PackedFloat64Array(input.get("q", []))
	var lower := PackedFloat64Array(input.get("lower", []))
	var upper := PackedFloat64Array(input.get("upper", []))
	var groups := PackedStringArray(input.get("joint_groups", []))
	var previous: Transform3D = input.get("previous_weapon", Transform3D.IDENTITY)
	var result := {"valid": false, "status": "INVALID_PROFILE", "reason": "allocator_input_invalid", "accepted_q": q, "accepted_weapon": previous, "accepted_payload": {}, "task_scale": 0.0, "iterations": 0, "revision": REVISION}
	if q.is_empty() or lower.size() != q.size() or upper.size() != q.size() or groups.size() != q.size() or not evaluate.is_valid() or str(input.get("origin_id", "")).is_empty():
		return result
	for i: int in q.size():
		if not is_finite(q[i]) or not is_finite(lower[i]) or not is_finite(upper[i]) or lower[i] > upper[i]:
			return result
	for key: String in ["position_tolerance", "orientation_tolerance", "max_rotation_step", "max_translation_step", "max_joint_step", "position_normalization", "finite_difference"]:
		if not is_finite(float(policy[key])) or float(policy[key]) <= 0.0:
			return result
	var mode := str(input.get("mode", ""))
	if mode not in ["tip", "pommel", "roll", "pose", "position"] or not input.get("target_weapon") is Transform3D or not input.get("contact_local") is Vector3:
		return result
	var posture := _posture_diagonal(input, groups, lower, upper, mode, policy)
	if not posture.valid:
		result.reason = posture.reason
		return result
	var target: Transform3D = input.target_weapon
	var contact: Vector3 = input.contact_local
	if not previous.is_finite() or not target.is_finite() or not contact.is_finite() or previous.basis.determinant() <= 0.0 or target.basis.determinant() <= 0.0:
		return result
	var task_point := contact
	if mode == "pommel" and input.has("task_point_local"):
		if not input.task_point_local is Vector3 or not (input.task_point_local as Vector3).is_finite():
			result.reason = "allocator_task_point_invalid"
			return result
		task_point = input.task_point_local
	if mode == "pommel" and input.has("trailing_tip_local"):
		if not input.trailing_tip_local is Vector3 or not (input.trailing_tip_local as Vector3).is_finite():
			result.reason = "allocator_trailing_tip_invalid"
			return result
		var trailing_weight := float(policy.get("pommel_tip_trailing_weight", 1.0))
		if not is_finite(trailing_weight) or trailing_weight < 0.0:
			result.reason = "allocator_trailing_weight_invalid"
			return result
	var path_validation := _validate_task_path(input, mode, previous, target, policy)
	if not path_validation.valid:
		result.reason = path_validation.reason
		return result
	var task_path: Dictionary = path_validation.path
	var anchor: Vector3 = previous * contact
	if mode == "roll" and input.has("contact_anchor"):
		if not input.contact_anchor is Vector3 or not (input.contact_anchor as Vector3).is_finite():
			result.reason = "allocator_contact_anchor_invalid"
			return result
		anchor = input.contact_anchor
	var initial: Dictionary = evaluate.call(q)
	var initial_validation := validate_initial_pose(input, initial, policy)
	if not initial_validation.valid:
		result.merge(initial_validation, true)
		return result
	var start_allowance := build_start_allowance(input, initial)
	lower = start_allowance.lower
	upper = start_allowance.upper
	var permitted_evaluate: Callable = func(values: PackedFloat64Array) -> Dictionary:
		return apply_start_allowance(evaluate.call(values), start_allowance)
	result.initial_warning = initial_validation.get("initial_warning", {})
	initial = apply_start_allowance(initial, start_allowance)
	var validator: Callable = input.get("validate_candidate", Callable())
	if not _candidate_valid(initial, validator):
		result.status = "RECOVERY_REQUIRED"
		result.reason = "allocator_initial_collision_or_context_invalid"
		return result
	result.accepted_payload = initial.get("payload", {})
	if not previous.basis.get_scale().is_equal_approx(target.basis.get_scale()):
		result.reason = "allocator_scale_change_forbidden"
		return result
	if mode == "roll" and (target * contact).distance_to(anchor) > float(policy.position_tolerance):
		result.reason = "allocator_rotation_changed_contact_anchor"
		return result
	var maximum_fraction := 1.0
	if mode == "pommel" and input.has("translation_reach_bound"):
		var supplied: Variant = input.translation_reach_bound
		if not supplied is Dictionary:
			result.reason = "allocator_translation_reach_bound_invalid"
			return result
		if bool(supplied.get("valid", false)):
			var fraction: Variant = supplied.get("maximum_fraction")
			if typeof(fraction) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(fraction)) or float(fraction) < 0.0 or float(fraction) > 1.0 or str(supplied.get("origin_id", "")) != str(input.origin_id):
				result.reason = "allocator_translation_reach_bound_invalid"
				return result
			maximum_fraction = float(fraction)
			result["translation_reach_bound"] = supplied.duplicate(true)
	var angle := 0.0 if mode in ["pommel", "position"] else _rotation_vector(target.basis, previous.basis).length()
	var distance := 0.0 if mode == "tip" else (target * task_point).distance_to(previous * task_point)
	if mode in ["pose", "position"]:
		distance = target.origin.distance_to(previous.origin)
	if not task_path.is_empty():
		distance = float(path_validation.arc_length)
	var count := maxi(1, int(ceil(maxf(angle / float(policy.max_rotation_step), distance / float(policy.max_translation_step)))))
	var accepted_fraction := 0.0
	var accepted_eval := initial
	var accepted_trailing_anchor: Variant = null
	var slide_target: Variant = null
	var attempted_failure := ""
	var reach_bound_reached := maximum_fraction == 0.0
	result["search_failures"] = []
	result["coverage_handoffs"] = []
	var max_substeps := maxi(1, int(policy.max_substeps))
	for step: int in mini(count, max_substeps):
		if reach_bound_reached:
			break
		# Keep count and fractions relative to the ORIGINAL demand. Rescaling
		# the target itself would report 100% despite only partial movement.
		var requested_fraction := minf(float(step + 1) / float(count), maximum_fraction)
		var requested := _target_at(previous, target, task_point, mode, requested_fraction, anchor, task_path)
		while true:
			var fit_start_q := q.duplicate()
			var attempted := _fit(q, requested, task_point, groups, lower, upper, input, permitted_evaluate, policy)
			result.iterations += int(attempted.iterations)
			if attempted.valid:
				attempted_failure = ""
				q = attempted.q
				accepted_eval = attempted.evaluation
				accepted_trailing_anchor = attempted.get("trailing_tip_anchor_world")
				accepted_fraction = requested_fraction
				if q != fit_start_q:
					_advance_accepted_checkpoint(input, accepted_eval)
				reach_bound_reached = maximum_fraction < 1.0 and requested_fraction >= maximum_fraction
				break
			attempted_failure = attempted.reason
			if result.search_failures.size() < 8:
				result.search_failures.append(_attempt_diagnostics(attempted, requested_fraction))
			# Forearm contact may make the exact pointer path impossible while
			# its tangential component remains usable. Retain only a fully legal,
			# improving contact-guided pose; never relax a grip or anatomical row.
			var slide := _try_clearance_slide(attempted, fit_start_q, requested, task_point,
				groups, lower, upper, input, permitted_evaluate, policy)
			if bool(input.get("allow_forearm_slide", false)) and bool(attempted.get("clearance_encountered", false)):
				if not result.has("clearance_slide_attempts"):
					result["clearance_slide_attempts"] = []
				if result.clearance_slide_attempts.size() < 8:
					result.clearance_slide_attempts.append({"fraction": requested_fraction,
						"valid": slide.get("valid", false), "reason": slide.get("slide_reason", ""),
						"detail": slide.get("slide_diagnostics", {})})
			if slide.get("valid", false):
				q = slide.q
				accepted_eval = slide.evaluation
				accepted_trailing_anchor = slide.get("trailing_tip_anchor_world")
				slide_target = slide.target
				var full_task := _task_vector(previous, target, task_point, float(policy.position_normalization), mode)
				var moved_task := _task_vector(previous, accepted_eval.weapon_frame, task_point, float(policy.position_normalization), mode)
				accepted_fraction = clampf(_dot(full_task, moved_task) / maxf(_norm_squared(full_task), NUMERIC_EPSILON), 0.0, 1.0)
				result.iterations += int(slide.get("iterations", 0))
				result["clearance_slide"] = true
				attempted_failure = "forearm_clearance_slide"
				_advance_accepted_checkpoint(input, accepted_eval)
				break
			# Common task scaling preserves the commanded path. Never scale the
			# joint vector and claim the nonlinear contact stayed fixed.
			var low := accepted_fraction
			var high := requested_fraction
			var start_fraction := accepted_fraction
			var start_q := q.duplicate()
			var coverage_failure := attempted.has("shoulder_boundary_diagnostics")
			for search: int in maxi(0, int(policy.scale_search_steps)):
				var middle := (low + high) * 0.5
				var smaller := _fit(start_q, _target_at(previous, target, task_point, mode, middle, anchor, task_path), task_point, groups, lower, upper, input, permitted_evaluate, policy)
				result.iterations += int(smaller.iterations)
				if smaller.valid:
					low = middle
					q = smaller.q
					accepted_eval = smaller.evaluation
					accepted_trailing_anchor = smaller.get("trailing_tip_anchor_world")
				else:
					coverage_failure = coverage_failure or smaller.has("shoulder_boundary_diagnostics")
					high = middle
					if result.search_failures.size() < 8:
						result.search_failures.append(_attempt_diagnostics(smaller, middle))
			accepted_fraction = low
			# Only a completed task-path fit may advance continuation state. The
			# adapter never changes its hold during FK probes, line search or the
			# bisection above. Keep the original target, tolerances and allowance.
			if coverage_failure and low > start_fraction + NUMERIC_EPSILON and q != start_q and result.coverage_handoffs.size() < MAX_COVERAGE_HANDOFFS_PER_REQUEST and _advance_accepted_checkpoint(input, accepted_eval):
				result.coverage_handoffs.append({"fraction": low,
					"shoulder_states": accepted_eval.get("payload", {}).get("shoulder_states_by_slot", {}).duplicate(true)})
				continue
			break
		if slide_target is Transform3D or accepted_fraction < requested_fraction - NUMERIC_EPSILON:
			break
	if reach_bound_reached:
		attempted_failure = "arm_extension_reach_limit"
	var requested_error := _task_pose_error(previous, target, task_point, mode)
	if q == PackedFloat64Array(input.q) and ((mode != "tip" and requested_error.position > float(policy.position_tolerance)) or requested_error.angle > float(policy.orientation_tolerance)):
		# Scaling a real command down inside the fit tolerance is not movement.
		# Report no progress instead of certifying an unchanged joint packet.
		accepted_fraction = 0.0
		if not reach_bound_reached:
			attempted_failure = "allocator_no_task_progress"
	result.accepted_q = q
	result.accepted_weapon = accepted_eval.weapon_frame
	result.accepted_payload = accepted_eval.get("payload", {})
	result.task_scale = accepted_fraction
	result.valid = accepted_fraction > NUMERIC_EPSILON
	result.status = "ACCEPTED" if accepted_fraction >= 1.0 - NUMERIC_EPSILON and not bool(result.get("clearance_slide", false)) else ("SCALED" if result.valid else "SEARCH_EXHAUSTED")
	result.reason = "" if result.status == "ACCEPTED" else (attempted_failure if not attempted_failure.is_empty() else "allocator_substep_budget")
	if result.has("translation_reach_bound"):
		result.translation_reach_bound["reached"] = reach_bound_reached
	var accepted_target := _target_at(previous, target, task_point, mode, accepted_fraction, anchor, task_path)
	if slide_target is Transform3D:
		accepted_target = slide_target
	var errors := _task_pose_error(accepted_eval.weapon_frame, accepted_target, task_point, mode)
	# Keep physical displacement visible without turning Tip translation into
	# a task or pivot-lock condition. Accepted_weapon is always actual joint FK.
	result.pivot_error = errors.position
	result.position_constrained = mode != "tip"
	result.orientation_constrained = mode not in ["pommel", "position"]
	if mode == "pommel":
		result.task_point_local = task_point
		result.task_point_world = (accepted_eval.weapon_frame as Transform3D) * task_point
		result.task_point_world_origin_id = input.origin_id
		if accepted_trailing_anchor is Vector3:
			result.trailing_tip_anchor_world = accepted_trailing_anchor
			result.trailing_tip_world = (accepted_eval.weapon_frame as Transform3D) * (input.trailing_tip_local as Vector3)
			result.trailing_tip_world_origin_id = input.origin_id
	result.contact_displacement = ((accepted_eval.weapon_frame as Transform3D) * contact).distance_to(previous * contact)
	result.contact_anchor = anchor if mode == "roll" else (accepted_eval.weapon_frame as Transform3D) * contact
	result.contact_anchor_origin_id = input.origin_id
	result.orientation_error = errors.angle
	result.remaining_task_error = _task_pose_error(accepted_eval.weapon_frame, target, task_point, mode)
	if mode == "tip":
		result.remaining_task_error.position = 0.0
	result.contributing_joint_groups = _contributing_groups(PackedFloat64Array(input.q), q, groups)
	var actual_evaluation: Dictionary = evaluate.call(q)
	var original_lower := PackedFloat64Array(input.lower)
	var original_upper := PackedFloat64Array(input.upper)
	result.pose_warning = _pose_warning(q, actual_evaluation, original_lower, original_upper, groups)
	result.active_limits = _active_limits(q, original_lower, original_upper, actual_evaluation)
	return result

## Optional adapter-owned continuation, invoked only between accepted fits.
## It may retain a boundary hold; it must not rebase anatomical references,
## mutate shared definitions, install bones or grant a new start allowance.
static func _advance_accepted_checkpoint(input: Dictionary, evaluation: Dictionary) -> bool:
	var advance: Callable = input.get("advance_accepted_checkpoint", Callable())
	return bool(advance.call(evaluation)) if advance.is_valid() else false

static func _attempt_diagnostics(attempt: Dictionary, fraction: float) -> Dictionary:
	var result := {"fraction": fraction, "reason": attempt.reason, "iterations": attempt.iterations,
		"qp": attempt.get("qp_diagnostics", {})}
	if attempt.has("rejection_counts"):
		result["rejection_counts"] = attempt.rejection_counts
		result["rejection_examples"] = attempt.rejection_examples
		result["initial_task_error_squared"] = attempt.get("initial_task_error_squared", 0.0)
	if attempt.has("stagnation_diagnostics"):
		result["stagnation_diagnostics"] = attempt.stagnation_diagnostics
	if attempt.has("shoulder_boundary_diagnostics"):
		result["shoulder_boundary_diagnostics"] = attempt.shoulder_boundary_diagnostics
	if attempt.has("trailing_tip_anchor_world"):
		result["trailing_tip_anchor_world"] = attempt.trailing_tip_anchor_world
	return result

## A current authored pose is input, not a new accepted candidate. Preserve
## finite/calibrated attachment checks, but describe anatomical excess instead
## of locking every control before it can be corrected.
static func validate_initial_pose(input: Dictionary, evaluation: Dictionary, policy: Dictionary) -> Dictionary:
	return validate_with_start_allowance(input, evaluation, policy, build_start_allowance(input, evaluation))

## Capture once from the actual starting pose. Never rebuild this allowance
## from a candidate or stored readback: doing so would permit outward creep.
static func build_start_allowance(input: Dictionary, evaluation: Dictionary) -> Dictionary:
	var q := PackedFloat64Array(input.q)
	var lower := PackedFloat64Array(input.lower)
	var upper := PackedFloat64Array(input.upper)
	var permitted_lower := lower.duplicate()
	var permitted_upper := upper.duplicate()
	if q.size() == lower.size() and q.size() == upper.size():
		for i: int in q.size():
			if is_finite(q[i]) and is_finite(lower[i]) and is_finite(upper[i]) and lower[i] <= upper[i]:
				permitted_lower[i] = minf(lower[i], q[i])
				permitted_upper[i] = maxf(upper[i], q[i])
	var values := PackedFloat64Array(evaluation.get("constraints", []))
	var names := PackedStringArray(evaluation.get("constraint_reasons", []))
	var offsets: Dictionary = {}
	for i: int in mini(values.size(), names.size()):
		if _anatomical_constraint(names[i]) and is_finite(values[i]) and values[i] > 0.0:
			# Reasons identify the same anatomical row in physical and search
			# arrays. Runtime supplies unique names, including side and joint.
			# Collision tolerance is an absolute small allowance at the surface,
			# not extra penetration granted on each new request. If already deep,
			# the permitted maximum remains exactly the inherited starting depth.
			offsets[names[i]] = maxf(0.0, values[i] - _constraint_tolerance(evaluation, i)) if names[i].begins_with("FOREARM_CLEARANCE:") else values[i]
	return {"lower": permitted_lower, "upper": permitted_upper, "offsets": offsets,
		"joint_groups": PackedStringArray(input.get("joint_groups", []))}

## Return copies; profile bounds and the caller's evaluation remain untouched.
## Contact rows/equalities are never shifted. Squared-norm derivative metadata
## belongs to physical contact rows and therefore remains unchanged as well.
static func apply_start_allowance(evaluation: Dictionary, allowance: Dictionary) -> Dictionary:
	var permitted := evaluation.duplicate()
	var offsets: Dictionary = allowance.get("offsets", {})
	var values := PackedFloat64Array(evaluation.get("constraints", [])).duplicate()
	var names := PackedStringArray(evaluation.get("constraint_reasons", []))
	for i: int in mini(values.size(), names.size()):
		if _anatomical_constraint(names[i]):
			values[i] -= float(offsets.get(names[i], 0.0))
	permitted.constraints = values
	if evaluation.has("search_constraints"):
		var search := PackedFloat64Array(evaluation.search_constraints).duplicate()
		var search_names := PackedStringArray(evaluation.get("search_constraint_reasons", []))
		for i: int in mini(search.size(), search_names.size()):
			if _anatomical_constraint(search_names[i]):
				search[i] -= float(offsets.get(search_names[i], 0.0))
		permitted.search_constraints = search
	return permitted

## Runtime uses the SAME original allowance to validate stored candidates.
## This is not permission to treat every newly written pose as a new baseline.
static func validate_with_start_allowance(input: Dictionary, evaluation: Dictionary, policy: Dictionary, allowance: Dictionary) -> Dictionary:
	var q := PackedFloat64Array(input.q)
	var original_lower := PackedFloat64Array(input.lower)
	var original_upper := PackedFloat64Array(input.upper)
	var groups := PackedStringArray(input.get("joint_groups", []))
	var lower := PackedFloat64Array(allowance.get("lower", []))
	var upper := PackedFloat64Array(allowance.get("upper", []))
	if q.size() != original_lower.size() or q.size() != original_upper.size() or q.size() != groups.size() or q.size() != lower.size() or q.size() != upper.size() or groups != PackedStringArray(allowance.get("joint_groups", [])):
		return {"valid": false, "status": "INVALID_PROFILE", "reason": "allocator_start_allowance_invalid"}
	for i: int in q.size():
		if not is_finite(q[i]) or not is_finite(original_lower[i]) or not is_finite(original_upper[i]) or original_lower[i] > original_upper[i] or not is_finite(lower[i]) or not is_finite(upper[i]) or lower[i] > upper[i]:
			return {"valid": false, "status": "INVALID_PROFILE", "reason": "allocator_input_invalid"}
	var permitted := apply_start_allowance(evaluation, allowance)
	if not _evaluation_valid(permitted) or not _legal(q, permitted, lower, upper):
		return {"valid": false, "status": "RECOVERY_REQUIRED", "reason": "allocator_initial_pose_invalid",
			"initial_diagnostics": _initial_diagnostics(q, permitted, lower, upper, groups)}
	var previous: Transform3D = input.previous_weapon
	var contact: Vector3 = input.contact_local
	var initial_error := _pose_error(evaluation.weapon_frame, previous, contact)
	if initial_error.position > float(policy.position_tolerance) or initial_error.angle > float(policy.orientation_tolerance):
		return {"valid": false, "status": "RECOVERY_REQUIRED", "reason": "allocator_initial_grip_mismatch"}
	if String(input.mode) == "roll":
		var anchor: Vector3 = input.get("contact_anchor", previous * contact)
		if maxf((previous * contact).distance_to(anchor), ((evaluation.weapon_frame as Transform3D) * contact).distance_to(anchor)) > float(policy.position_tolerance):
			return {"valid": false, "status": "RECOVERY_REQUIRED", "reason": "allocator_initial_contact_drift"}
	var warning := _pose_warning(q, evaluation, original_lower, original_upper, groups)
	return {"valid": true, "initial_warning": warning, "pose_warning": warning}

static func _anatomical_constraint(name: String) -> bool:
	# Forearm penetration inherited at request start is a recovery allowance,
	# never permission to deepen it. Contact and shoulder-hold rows stay strict.
	return name.begins_with("JOINT_RANGE:") or name.begins_with("COUPLED_LIMIT:") or name.begins_with("FOREARM_CLEARANCE:")

static func _touches_forearm_clearance(evaluation: Dictionary, threshold: float = 0.0001) -> bool:
	var values := _constraints(evaluation)
	var reasons := PackedStringArray(evaluation.get("constraint_reasons", []))
	for index: int in mini(values.size(), reasons.size()):
		if reasons[index].begins_with("FOREARM_CLEARANCE:") and values[index] >= -threshold:
			return true
	return false

static func _moving_forearm_boundary(evaluation: Dictionary, gradients: Array) -> bool:
	var values := _search_constraints(evaluation)
	var reasons := PackedStringArray(evaluation.get("search_constraint_reasons", evaluation.get("constraint_reasons", [])))
	for index: int in mini(values.size(), reasons.size()):
		if reasons[index].begins_with("FOREARM_CLEARANCE:") and values[index] >= -0.0001 and index < gradients.size() and _norm_squared(gradients[index]) > NUMERIC_EPSILON:
			return true
	return false

static func _moving_forearm_step_blocked(before: Dictionary, after: Dictionary) -> bool:
	if not _evaluation_valid(after):
		return false
	var first := _constraints(before)
	var second := _constraints(after)
	var reasons := PackedStringArray(after.get("constraint_reasons", []))
	for index: int in mini(mini(first.size(), second.size()), reasons.size()):
		if reasons[index].begins_with("FOREARM_CLEARANCE:") and second[index] > _constraint_tolerance(after, index) and second[index] > first[index] + NUMERIC_EPSILON:
			return true
	return false

## A contact-guided partial task is deliberately separate from ordinary task
## scaling. Pommel follows its controlled point; Roll keeps its anchor.
## This branch cannot run unless a real forearm clearance row was encountered.
static func _try_clearance_slide(attempt: Dictionary, start: PackedFloat64Array,
		target: Transform3D, contact: Vector3, groups: PackedStringArray,
		lower: PackedFloat64Array, upper: PackedFloat64Array, input: Dictionary,
		evaluate: Callable, policy: Dictionary) -> Dictionary:
	if not bool(input.get("allow_forearm_slide", false)) or not bool(attempt.get("clearance_encountered", false)):
		return {"valid": false, "slide_reason": "no_moving_clearance_encounter"}
	var best := PackedFloat64Array(attempt.get("best_q", start))
	var evaluation: Dictionary = attempt.get("best_evaluation", {})
	var diagnostics := {"best_available": attempt.has("best_q"), "best_changed": best != start,
		"best_evaluation_valid": _evaluation_valid(evaluation)}
	if best == start or not _evaluation_valid(evaluation):
		return {"valid": false, "slide_reason": "no_valid_partial_progress", "slide_diagnostics": diagnostics}
	diagnostics["best_legal"] = _legal(best, evaluation, lower, upper)
	diagnostics["best_touches_clearance"] = _touches_forearm_clearance(evaluation)
	diagnostics["best_task_error"] = _task_pose_error(evaluation.weapon_frame, target, contact, String(input.mode))
	diagnostics["best_constraints"] = _initial_diagnostics(best, evaluation, lower, upper, groups)
	var clearance_rows: Array[Dictionary] = []
	var values := _constraints(evaluation)
	var reasons := PackedStringArray(evaluation.get("constraint_reasons", []))
	for index: int in mini(values.size(), reasons.size()):
		if reasons[index].begins_with("FOREARM_CLEARANCE:") and values[index] >= -0.01:
			clearance_rows.append({"reason": reasons[index], "value": values[index],
				"tolerance": _constraint_tolerance(evaluation, index)})
	diagnostics["near_clearance_rows"] = clearance_rows
	if not diagnostics.best_legal:
		return {"valid": false, "slide_reason": "partial_not_legal", "slide_diagnostics": diagnostics}
	var mode := String(input.mode)
	var projected: Transform3D = evaluation.weapon_frame
	if mode == "roll":
		var anchor: Vector3 = input.get("contact_anchor", (input.previous_weapon as Transform3D) * contact)
		projected.origin = anchor - projected.basis * contact
	var polished := _fit(best, projected, contact, groups, lower, upper, input, evaluate, policy)
	if not polished.valid or PackedFloat64Array(polished.q) == start:
		diagnostics["polish_reason"] = polished.get("reason", "")
		diagnostics["polish_iterations"] = polished.get("iterations", 0)
		diagnostics["polish_best_available"] = polished.has("best_q")
		if _evaluation_valid(polished.get("best_evaluation", {})):
			diagnostics["polish_best_error"] = _task_pose_error(polished.best_evaluation.weapon_frame, projected, contact, mode)
		return {"valid": false, "slide_reason": "strict_projected_pose_polish_failed", "slide_diagnostics": diagnostics}
	var from: Dictionary = evaluate.call(start)
	var old_error := _norm_squared(_task_vector(from.weapon_frame, target, contact, float(policy.position_normalization), mode))
	var new_error := _norm_squared(_task_vector(polished.evaluation.weapon_frame, target, contact, float(policy.position_normalization), mode))
	if new_error >= old_error - 1.0e-16:
		return {"valid": false, "slide_reason": "projected_pose_did_not_improve", "slide_diagnostics": diagnostics}
	polished["target"] = projected
	polished["slide_reason"] = "legal_projected_pose"
	polished["slide_diagnostics"] = diagnostics
	if attempt.has("trailing_tip_anchor_world"):
		polished["trailing_tip_anchor_world"] = attempt.trailing_tip_anchor_world
	return polished

static func _pose_warning(q: PackedFloat64Array, evaluation: Dictionary, lower: PackedFloat64Array, upper: PackedFloat64Array, groups: PackedStringArray) -> Dictionary:
	return {} if _evaluation_valid(evaluation) and _legal(q, evaluation, lower, upper) else _initial_diagnostics(q, evaluation, lower, upper, groups)

static func _fit(start: PackedFloat64Array, target: Transform3D, contact: Vector3, groups: PackedStringArray, lower: PackedFloat64Array, upper: PackedFloat64Array, input: Dictionary, evaluate: Callable, policy: Dictionary) -> Dictionary:
	var q := start.duplicate()
	var evaluation: Dictionary = evaluate.call(q)
	var validator: Callable = input.get("validate_candidate", Callable())
	var mode := String(input.mode)
	var response := {"valid": false, "q": start, "evaluation": evaluation, "iterations": 0, "reason": "allocator_search_exhausted"}
	var allow_clearance_slide: bool = bool(input.get("allow_forearm_slide", false))
	response["clearance_encountered"] = false
	var posture := _posture_diagonal(input, groups, lower, upper, mode, policy)
	if not posture.valid:
		response.reason = posture.reason
		return response
	var trailing_weight := float(policy.get("pommel_tip_trailing_weight", 1.0))
	var trailing_tip: Variant = input.get("trailing_tip_local") if mode == "pommel" and trailing_weight > 0.0 and not _uses_exact_hold_order(mode, policy) else null
	# The reference belongs to this fit's accepted starting frame in the same
	# input.origin_id as FK. Newton/trials cannot move it; each next accepted
	# spatial substep starts a fresh fit. No time lag or new anatomical zero.
	var previous_tip := Vector3.ZERO
	if trailing_tip is Vector3:
		previous_tip = (evaluation.weapon_frame as Transform3D) * (trailing_tip as Vector3)
		response["trailing_tip_anchor_world"] = previous_tip
	var shoulder_crossing_iterations := 0
	# Diagnostic-only, opt-in through the per-request policy override. No
	# persistent logs or additional candidate/scene evaluations are introduced.
	var trace_rejections := bool(policy.get("trace_rejections", false))
	if trace_rejections:
		response["rejection_counts"] = {}
		response["rejection_examples"] = []
	for iteration: int in maxi(1, int(policy.max_iterations)):
		response.iterations = iteration + 1
		var error := _task_pose_error(evaluation.weapon_frame, target, contact, mode)
		if _legal(q, evaluation, lower, upper) and (mode == "tip" or error.position <= float(policy.position_tolerance)) and error.angle <= float(policy.orientation_tolerance):
			if not _candidate_valid(evaluation, validator):
				response.reason = "allocator_candidate_collision_or_context_invalid"
				return response
			response.valid = true
			response.q = q
			response.evaluation = evaluation
			return response
		var differential := _differentiate(q, evaluation, contact, evaluate, policy, lower, upper, mode, trailing_tip)
		if not differential.valid:
			response.reason = "allocator_invalid_forward_sample"
			return response
		response.clearance_encountered = response.clearance_encountered or (allow_clearance_slide and _moving_forearm_boundary(evaluation, differential.constraints))
		var jacobian: Array = differential.jacobian
		var residual := _task_vector(evaluation.weapon_frame, target, contact, float(policy.position_normalization), mode)
		if trace_rejections and not response.has("initial_task_error_squared"):
			response["initial_task_error_squared"] = _norm_squared(residual)
		var inequalities: Array = []
		var limits := PackedFloat64Array()
		var step_sizes := PackedFloat64Array(input.get("step_sizes", []))
		for i: int in q.size():
			var extent: float = step_sizes[i] if step_sizes.size() == q.size() else float(policy.max_joint_step)
			var row := _zeros(q.size())
			row[i] = 1.0
			inequalities.append(row)
			limits.append(maxf(0.0, minf(upper[i] - q[i], extent)))
			row = _zeros(q.size())
			row[i] = -1.0
			inequalities.append(row)
			limits.append(maxf(0.0, minf(q[i] - lower[i], extent)))
		var constraint_values := _search_constraints(evaluation)
		for i: int in constraint_values.size():
			inequalities.append(differential.constraints[i])
			limits.append(maxf(0.0, -constraint_values[i]))
		var hessian := _gram(jacobian, q.size())
		var gradient := _transpose_product(jacobian, residual, -1.0)
		var optimized := _qp(hessian, gradient, [], inequalities, limits, _zeros(q.size()))
		if not optimized.valid:
			response.reason = "allocator_qp_search_exhausted"
			response["qp_diagnostics"] = {"stage": "task", "reason": optimized.get("reason", ""), "active": optimized.get("active", []), "trace": optimized.get("trace", [])}
			return response
		var delta: PackedFloat64Array = optimized.x
		# The task remains strict priority. A single finite positive posture QP
		# only redistributes its achieved step within that same task nullspace.
		var equalities: Array = jacobian.duplicate()
		if not _uses_exact_hold_order(mode, policy):
			var h := _matrix(q.size(), q.size())
			var g := _zeros(q.size())
			for i: int in q.size():
				h[i][i] = posture.diagonal[i]
				g[i] = (q[i] - start[i]) * float(posture.diagonal[i])
			var fallback_h: Array = []
			var fallback_g := PackedFloat64Array()
			if trailing_tip is Vector3:
				fallback_h = h.duplicate(true)
				fallback_g = g.duplicate()
				var tip_jacobian: Array = differential.trailing_tip_jacobian
				var tip_error: Vector3 = ((evaluation.weapon_frame as Transform3D) * (trailing_tip as Vector3) - previous_tip) / float(policy.position_normalization)
				# Finite weight, dimensionless like the primary position task. This is
				# a soft geometric preference alongside joint posture; the three
				# primary task rows above preserve Pommel's achieved linear step.
				var tip_h := _gram(tip_jacobian, q.size())
				var tip_g := _transpose_product(tip_jacobian, PackedFloat64Array([tip_error.x, tip_error.y, tip_error.z]), 1.0)
				for i: int in q.size():
					g[i] += tip_g[i] * trailing_weight
					for j: int in q.size():
						h[i][j] += tip_h[i][j] * trailing_weight
			var preferred := _qp(h, g, equalities, inequalities, limits, delta)
			if not preferred.valid and trailing_tip is Vector3:
				# A secondary preference must not turn a previously usable primary
				# step into a blocker if this extra objective is ill-conditioned.
				preferred = _qp(fallback_h, fallback_g, equalities, inequalities, limits, delta)
			if not preferred.valid:
				response.reason = "allocator_posture_search_exhausted"
				response["qp_diagnostics"] = {"stage": "posture", "reason": preferred.get("reason", ""), "active": preferred.get("active", []), "trace": preferred.get("trace", [])}
				return response
			delta = preferred.x
		# Explicit diagnostic/fixture overrides retain exact historical tiers.
		var hold_order: Array = _hold_order(mode, policy) if _uses_exact_hold_order(mode, policy) else []
		for tier: PackedStringArray in hold_order:
			var indices := PackedInt32Array()
			for i: int in groups.size():
				if groups[i] in tier and upper[i] - lower[i] > NUMERIC_EPSILON:
					indices.append(i)
			if indices.is_empty():
				continue
			var h := _matrix(q.size(), q.size())
			var g := _zeros(q.size())
			for i: int in indices:
				var span := maxf(upper[i] - lower[i], 0.0001)
				h[i][i] = 1.0 / (span * span)
				g[i] = (q[i] - start[i]) / (span * span)
			var preferred := _qp(h, g, equalities, inequalities, limits, delta)
			if not preferred.valid:
				response.reason = "allocator_priority_search_exhausted"
				response["qp_diagnostics"] = {"stage": "priority", "tier": tier, "reason": preferred.get("reason", ""), "active": preferred.get("active", []), "trace": preferred.get("trace", [])}
				return response
			delta = preferred.x
			for i: int in indices:
				var row := _zeros(q.size())
				row[i] = 1.0
				equalities.append(row)
		if _norm_squared(delta) < 1.0e-16:
			response.reason = "allocator_no_local_progress"
			return response
		var old_error := _norm_squared(residual)
		if mode == "pommel" and bool(input.get("translation_reach_bound", {}).get("valid", false)):
			# At the fixed-shoulder reach boundary a nonzero joint step can
			# improve only finite-difference noise. Do not spend ten nonlinear
			# trials on progress below 1/1000 of the existing task tolerances.
			# This stops a search; it never accepts or loosens a pose. The outer
			# path-fraction search can still find a genuinely reachable target.
			var linear_residual := residual.duplicate()
			for row: int in jacobian.size():
				linear_residual[row] -= _dot(jacobian[row], delta)
			var predicted_gain := sqrt(old_error) - sqrt(_norm_squared(linear_residual))
			var progress_floor := minf(float(policy.orientation_tolerance), float(policy.position_tolerance) / float(policy.position_normalization)) * 0.001
			if predicted_gain <= progress_floor:
				response.reason = "allocator_numerical_stagnation"
				response["stagnation_diagnostics"] = {"predicted_residual_gain": predicted_gain,
					"progress_floor": progress_floor, "delta_squared": _norm_squared(delta),
					"old_task_error_squared": old_error, "predicted_task_error_squared": _norm_squared(linear_residual)}
				return response
		var advanced := false
		var fraction := 1.0
		var crossed_shoulder_coverage := false
		for line_search: int in 10:
			var trial := _add(q, delta, fraction)
			var trial_eval: Dictionary = evaluate.call(trial)
			response.clearance_encountered = response.clearance_encountered or (allow_clearance_slide and _moving_forearm_step_blocked(evaluation, trial_eval))
			var before_restore: Dictionary = {}
			if _evaluation_valid(trial_eval) and not _legal(trial, trial_eval, lower, upper):
				# A covered shoulder can change h, but an uncovered trial must
				# retain the request's fixed h anchor. Repeatedly crossing that
				# discontinuity and restoring the old anchor can consume thousands
				# of FK calls without reaching the task. Bound only that repeated
				# Pommel search, then let the ordinary path-fraction search retain
				# a legal boundary pose. Do not rebase h inside candidate evaluation.
				if mode in ["pommel", "pose", "position"] and not crossed_shoulder_coverage and _enters_shoulder_hold(evaluation, trial_eval):
					crossed_shoulder_coverage = true
					shoulder_crossing_iterations += 1
					if shoulder_crossing_iterations >= MAX_SHOULDER_COVERAGE_CROSSING_ITERATIONS:
						response.reason = "allocator_shoulder_coverage_boundary"
						response["shoulder_boundary_diagnostics"] = {"crossing_iterations": shoulder_crossing_iterations,
							"iteration": iteration, "line_search": line_search,
							"current_shoulder_states": evaluation.get("payload", {}).get("shoulder_states_by_slot", {}),
							"trial_shoulder_states": trial_eval.get("payload", {}).get("shoulder_states_by_slot", {})}
						return response
				if trace_rejections and response.rejection_examples.size() < 8:
					before_restore = _initial_diagnostics(trial, trial_eval, lower, upper, groups)
				var restored := _restore_feasible(trial, trial_eval, evaluate, lower, upper, policy)
				trial = restored.q
				trial_eval = restored.evaluation
			var rejected_stage := "nonlinear_bounds_or_fk"
			var transition_detail: Dictionary = {}
			var next_error := INF
			if _evaluation_valid(trial_eval) and _legal(trial, trial_eval, lower, upper):
				next_error = _norm_squared(_task_vector(trial_eval.weapon_frame, target, contact, float(policy.position_normalization), mode))
				rejected_stage = "task_error_did_not_improve"
				if next_error < old_error - 1.0e-16:
					rejected_stage = "candidate_storage_or_collision"
					if _candidate_valid(trial_eval, validator):
						rejected_stage = "intermediate_transition"
						if trace_rejections:
							transition_detail["enabled"] = true
						if _transition_legal(q, trial, evaluate, lower, upper, validator, transition_detail):
							q = trial
							evaluation = trial_eval
							response["best_q"] = q
							response["best_evaluation"] = evaluation
							advanced = true
							break
			if trace_rejections:
				response.rejection_counts[rejected_stage] = int(response.rejection_counts.get(rejected_stage, 0)) + 1
				if response.rejection_examples.size() < 8:
					# _task_vector is target minus current: J*delta reduces that
					# residual. Use the existing linearization, with no FK calls.
					var predicted := residual.duplicate()
					var restored_prediction := residual.duplicate()
					var restored_delta := trial.duplicate()
					for column: int in q.size():
						restored_delta[column] -= q[column]
					for row: int in jacobian.size():
						predicted[row] -= fraction * _dot(jacobian[row], delta)
						restored_prediction[row] -= _dot(jacobian[row], restored_delta)
					response.rejection_examples.append({"stage": rejected_stage, "iteration": iteration,
						"line_search": line_search, "step_fraction": fraction, "old_task_error_squared": old_error,
						"predicted_task_error_squared": _norm_squared(predicted),
						"restored_linear_task_error_squared": _norm_squared(restored_prediction),
						"delta_squared": _norm_squared(delta),
						"new_task_error_squared": next_error, "before_restore": before_restore,
						"after_restore": _initial_diagnostics(trial, trial_eval, lower, upper, groups),
						"shoulder_states": trial_eval.get("payload", {}).get("shoulder_states_by_slot", {}),
						"transition": transition_detail})
			fraction *= 0.5
		if not advanced:
			response.reason = "allocator_nonlinear_step_blocked"
			return response
	return response

static func _enters_shoulder_hold(before: Dictionary, after: Dictionary) -> bool:
	var previous_states: Dictionary = before.get("payload", {}).get("shoulder_states_by_slot", {})
	var next_states: Dictionary = after.get("payload", {}).get("shoulder_states_by_slot", {})
	var values := _constraints(after)
	var reasons := PackedStringArray(after.get("constraint_reasons", []))
	for slot: Variant in next_states:
		if previous_states.get(slot) is Dictionary and next_states[slot] is Dictionary:
			if not previous_states[slot].has("held_h") and next_states[slot].has("held_h"):
				# Entering uncovered space alone is not a failed transition. The
				# fixed h may already be satisfied while another joint is illegal.
				# Only this same arm's active hold can consume this search budget.
				for index: int in mini(values.size(), reasons.size()):
					if values[index] > CONSTRAINT_EPSILON and reasons[index].begins_with("SHOULDER_HOLD:") and reasons[index].ends_with(":" + String(slot)):
						return true
	return false

## A tangent to a curved inequality can lie outside it at second order.
## Retract that *internal candidate* to the nonlinear feasible region, then
## continue the exact weapon-task fit. A retracted but detached grip is never
## accepted merely because its joint limits pass.
static func _restore_feasible(candidate: PackedFloat64Array, candidate_eval: Dictionary, evaluate: Callable, lower: PackedFloat64Array, upper: PackedFloat64Array, policy: Dictionary) -> Dictionary:
	var q := candidate.duplicate()
	var evaluation := candidate_eval
	var epsilon := float(policy.finite_difference)
	for iteration: int in 8:
		for i: int in q.size():
			q[i] = clampf(q[i], lower[i], upper[i])
		evaluation = evaluate.call(q)
		if not _evaluation_valid(evaluation) or _legal(q, evaluation, lower, upper):
			break
		var values := _constraints(evaluation)
		var worst := -1
		var excess := CONSTRAINT_EPSILON
		for row: int in values.size():
			if values[row] > _constraint_tolerance(evaluation, row) and values[row] > excess:
				excess = values[row]
				worst = row
		if worst < 0:
			break
		var gradient := _zeros(q.size())
		for column: int in q.size():
			if upper[column] - lower[column] <= NUMERIC_EPSILON:
				continue
			var altered := q.duplicate()
			altered[column] += epsilon
			var sample: Dictionary = evaluate.call(altered)
			if not _evaluation_valid(sample):
				continue
			gradient[column] = _constraint_slope(evaluation, sample, worst, values[worst], _constraints(sample)[worst], epsilon)
		var norm := _norm_squared(gradient)
		if norm <= PIVOT_EPSILON:
			break
		q = _add(q, gradient, -(excess + CONSTRAINT_EPSILON * 0.25) / norm)
	for i: int in q.size():
		q[i] = clampf(q[i], lower[i], upper[i])
	evaluation = evaluate.call(q)
	return {"q": q, "evaluation": evaluation}

static func _differentiate(q: PackedFloat64Array, evaluation: Dictionary, contact: Vector3, evaluate: Callable, policy: Dictionary, lower: PackedFloat64Array, upper: PackedFloat64Array, mode: String = "", trailing_tip: Variant = null) -> Dictionary:
	var base_constraints := _search_constraints(evaluation)
	var custom_search: bool = evaluation.has("search_constraints")
	var task_rows := 3 if mode in ["tip", "pommel", "position"] else 6
	var j := _matrix(task_rows, q.size())
	var c := _matrix(base_constraints.size(), q.size())
	var tip_jacobian: Array = _matrix(3, q.size()) if trailing_tip is Vector3 else []
	var tip_origin := Vector3.ZERO
	if trailing_tip is Vector3:
		tip_origin = (evaluation.weapon_frame as Transform3D) * (trailing_tip as Vector3)
	var epsilon := float(policy.finite_difference)
	for column: int in q.size():
		# Effective bounds already include the original-pose correction allowance.
		# A genuinely fixed coordinate has no feasible delta: retain its zero
		# column without evaluating an impossible perturbation. Do not round a
		# narrow but nonzero interval into a lock.
		if lower[column] == upper[column]:
			continue
		var altered := q.duplicate()
		altered[column] += epsilon
		var sample: Dictionary = evaluate.call(altered)
		if not _evaluation_valid(sample):
			return {"valid": false}
		var values := _search_constraints(sample)
		if values.size() != base_constraints.size():
			return {"valid": false}
		var displacement := _task_vector(evaluation.weapon_frame, sample.weapon_frame, contact, float(policy.position_normalization), mode)
		for row: int in task_rows:
			j[row][column] = displacement[row] / epsilon
		if trailing_tip is Vector3:
			# Reuse this exact FK sample; trailing adds no scene evaluation.
			var tip_delta: Vector3 = ((sample.weapon_frame as Transform3D) * (trailing_tip as Vector3) - tip_origin) / (float(policy.position_normalization) * epsilon)
			for row: int in 3:
				tip_jacobian[row][column] = tip_delta[row]
		for row: int in values.size():
			# Custom search rows have their own indexing. Physical norm metadata
			# must never be applied to a search slab at the same numeric index.
			c[row][column] = (values[row] - base_constraints[row]) / epsilon if custom_search else _constraint_slope(evaluation, sample, row, base_constraints[row], values[row], epsilon)
	var result := {"valid": true, "jacobian": j, "constraints": c}
	if trailing_tip is Vector3:
		result["trailing_tip_jacobian"] = tip_jacobian
	return result

static func _constraint_slope(base: Dictionary, sample: Dictionary, row: int, base_value: float, sample_value: float, epsilon: float) -> float:
	var base_residuals: Dictionary = base.get("squared_norm_residuals", {})
	var sample_residuals: Dictionary = sample.get("squared_norm_residuals", {})
	if base_residuals.get(row) is Vector3 and sample_residuals.get(row) is Vector3:
		var residual: Vector3 = base_residuals[row]
		return 2.0 * residual.dot(((sample_residuals[row] as Vector3) - residual) / epsilon)
	return (sample_value - base_value) / epsilon

## Feasible active-set convex QP. Equalities preserve their initial x value;
## inequality starts must already be feasible. Singular PSD Hessians are
## intentional for lexicographic groups; rank-revealing elimination handles
## free variables without adding a competing regularization objective.
static func _qp(h: Array, g: PackedFloat64Array, equalities: Array, inequalities: Array, limits: PackedFloat64Array, initial: PackedFloat64Array) -> Dictionary:
	return MotionMath.qp(h, g, equalities, inequalities, limits, initial)

static func _uses_exact_hold_order(mode: String, policy: Dictionary) -> bool:
	return policy.get("hold_order_by_mode", {}).has(mode) or String(policy.get("posture_preference_mode", "weighted")) == "lexicographic"

## Costs normalize travel by a fixed coordinate span, not distance to a moving
## limit. Anatomical coupled constraints remain the actual feasibility owner.
## An adapter can supply a cone's true span when its exponential coordinates
## have a much wider search box. No input/resource is modified here.
static func _posture_diagonal(input: Dictionary, groups: PackedStringArray, lower: PackedFloat64Array, upper: PackedFloat64Array, mode: String, policy: Dictionary) -> Dictionary:
	if String(policy.get("posture_preference_mode", "weighted")) not in ["weighted", "lexicographic"]:
		return {"valid": false, "reason": "allocator_posture_mode_invalid"}
	if not policy.get("hold_order_by_mode", {}) is Dictionary:
		return {"valid": false, "reason": "allocator_posture_hold_override_invalid"}
	if _uses_exact_hold_order(mode, policy):
		return {"valid": true, "diagonal": PackedFloat64Array()}
	var spans := PackedFloat64Array()
	if input.has("posture_spans"):
		if not input.posture_spans is PackedFloat64Array or input.posture_spans.size() != groups.size():
			return {"valid": false, "reason": "allocator_posture_spans_invalid"}
		spans = input.posture_spans
		for span: float in spans:
			if not is_finite(span) or span <= 0.0:
				return {"valid": false, "reason": "allocator_posture_spans_invalid"}
	var all_costs: Variant = policy.get("posture_group_costs_by_mode", {})
	if not all_costs is Dictionary:
		return {"valid": false, "reason": "allocator_posture_costs_invalid"}
	var default_mode := "pommel" if mode in ["pose", "position"] else mode
	var costs: Variant = all_costs.get(mode, all_costs.get(default_mode, {}))
	if not costs is Dictionary:
		return {"valid": false, "reason": "allocator_posture_costs_invalid"}
	var diagonal := PackedFloat64Array()
	for i: int in groups.size():
		var cost: Variant = costs.get(groups[i], 1.0)
		if typeof(cost) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(cost)) or float(cost) <= 0.0:
			return {"valid": false, "reason": "allocator_posture_costs_invalid"}
		var span := spans[i] if not spans.is_empty() else maxf(upper[i] - lower[i], 0.0001)
		# Locked coordinates have zero feasible motion; avoid a giant meaningless
		# diagonal while retaining a positive-definite preference Hessian.
		var weight := 1.0 if lower[i] == upper[i] else float(cost) / (span * span)
		if not is_finite(weight) or weight <= 0.0:
			return {"valid": false, "reason": "allocator_posture_costs_invalid"}
		diagonal.append(weight)
	return {"valid": true, "diagonal": diagonal}

static func _hold_order(mode: String, policy: Dictionary) -> Array:
	if policy.get("hold_order_by_mode", {}).has(mode):
		return policy.hold_order_by_mode[mode]
	# Ordered minimization is the reverse of preferred contribution. These
	# groups remain available for necessary geometric compensation at every step.
	if mode in ["pommel", "pose", "position"]:
		return [PackedStringArray(["torso"]), PackedStringArray(["girdle", "shoulder_girdle"]), PackedStringArray(["wrist", "forearm"]), PackedStringArray(["shoulder", "shoulder_swing", "shoulder_roll", "elbow"])]
	if mode == "roll":
		return [PackedStringArray(["torso"]), PackedStringArray(["girdle", "shoulder_girdle"]), PackedStringArray(["shoulder", "shoulder_roll"]), PackedStringArray(["wrist", "elbow", "shoulder_swing"]), PackedStringArray(["forearm"])]
	# Tip rotation can use forearm turn before bending the elbow/wrist. Holding
	# forearm first forced opposing distal corrections near a singular wrist
	# configuration. Shoulder and elbow remain available when the actual task
	# Jacobian and distal bounds require them. Keep the existing proximal hold
	# policy so a wrist-bend correction does not become an upstream rotation.
	# These are preferences, not per-joint travel allowances or new DOFs.
	return [PackedStringArray(["torso"]), PackedStringArray(["girdle", "shoulder_girdle"]), PackedStringArray(["shoulder", "shoulder_swing", "shoulder_roll"]), PackedStringArray(["elbow"]), PackedStringArray(["wrist"]), PackedStringArray(["forearm"])]

## Path data is request-local geometry in input.origin_id, never a new bone
## reference or a pose limit. Normalize only after checking the supplied axis;
## confirm the complete orbit reaches the caller's requested endpoint.
static func _validate_task_path(input: Dictionary, mode: String, previous: Transform3D, target: Transform3D, policy: Dictionary) -> Dictionary:
	if not input.has("task_path"):
		return {"valid": true, "path": {}}
	if mode != "position":
		return {"valid": false, "reason": "allocator_task_path_mode_invalid"}
	var supplied: Variant = input.task_path
	if not supplied is Dictionary or String(supplied.get("kind", "")) != "orbit":
		return {"valid": false, "reason": "allocator_task_path_invalid"}
	var center: Variant = supplied.get("center")
	var axis: Variant = supplied.get("axis")
	var angle: Variant = supplied.get("angle_radians")
	if not center is Vector3 or not center.is_finite() or not axis is Vector3 or not axis.is_finite() or axis.length_squared() <= 1.0e-12:
		return {"valid": false, "reason": "allocator_task_path_geometry_invalid"}
	if typeof(angle) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(angle)):
		return {"valid": false, "reason": "allocator_task_path_angle_invalid"}
	var direction: Vector3 = (axis as Vector3).normalized()
	var offset: Vector3 = previous.origin - center
	var endpoint: Vector3 = center + Basis(direction, float(angle)) * offset
	if not endpoint.is_finite() or endpoint.distance_to(target.origin) > float(policy.position_tolerance):
		return {"valid": false, "reason": "allocator_task_path_endpoint_mismatch"}
	var radius: float = (offset - direction * offset.dot(direction)).length()
	var arc_length: float = radius * absf(float(angle))
	if not is_finite(arc_length):
		return {"valid": false, "reason": "allocator_task_path_geometry_invalid"}
	return {"valid": true, "path": {"kind": "orbit", "center": center, "axis": direction, "angle_radians": float(angle)},
		"arc_length": arc_length}

static func _target_at(previous: Transform3D, target: Transform3D, contact: Vector3, mode: String, weight: float, anchor: Vector3, path: Dictionary = {}) -> Transform3D:
	if mode == "position" and not path.is_empty():
		return Transform3D(previous.basis, (path.center as Vector3) + Basis(path.axis, float(path.angle_radians) * weight) * (previous.origin - (path.center as Vector3)))
	if mode == "pommel":
		# Basis is descriptive here, never an angular task. Interpolate the
		# addressed WeaponRoot-local point so rotation cannot move the marker
		# away from its pointer path or substitute handle travel for Pommel travel.
		var point: Vector3 = (previous * contact).lerp(target * contact, weight)
		return Transform3D(previous.basis, point - previous.basis * contact)
	if mode == "position":
		return Transform3D(previous.basis, previous.origin.lerp(target.origin, weight))
	var rotation := previous.basis.orthonormalized().get_rotation_quaternion().slerp(target.basis.orthonormalized().get_rotation_quaternion(), weight)
	var basis := Basis(rotation).scaled(previous.basis.get_scale())
	if mode in ["tip", "pose"]:
		# Pose interpolates its frame origin; Tip keeps that origin descriptive
		# only because its residual/Jacobian contain no translation rows.
		return Transform3D(basis, previous.origin.lerp(target.origin, weight))
	return Transform3D(basis, anchor - basis * contact)

static func _pose_error(current: Transform3D, target: Transform3D, contact: Vector3) -> Dictionary:
	return {"position": (current * contact).distance_to(target * contact), "angle": _rotation_vector(target.basis, current.basis).length()}

static func _task_pose_error(current: Transform3D, target: Transform3D, contact: Vector3, mode: String) -> Dictionary:
	if mode == "pommel":
		return {"position": (current * contact).distance_to(target * contact), "angle": 0.0}
	if mode in ["pose", "position"]:
		return {"position": current.origin.distance_to(target.origin),
			"angle": 0.0 if mode == "position" else _rotation_vector(target.basis, current.basis).length()}
	return _pose_error(current, target, contact)

static func _task_vector(current: Transform3D, target: Transform3D, contact: Vector3, length_scale: float, mode: String = "") -> PackedFloat64Array:
	var angular := _rotation_vector(target.basis, current.basis)
	if mode == "tip":
		return PackedFloat64Array([angular.x, angular.y, angular.z])
	var position := (target.origin - current.origin) / length_scale if mode in ["pose", "position"] else (target * contact - current * contact) / length_scale
	if mode in ["pommel", "position"]:
		return PackedFloat64Array([position.x, position.y, position.z])
	return PackedFloat64Array([position.x, position.y, position.z, angular.x, angular.y, angular.z])

static func _rotation_vector(target: Basis, current: Basis) -> Vector3:
	var rotation := (target.orthonormalized().get_rotation_quaternion() * current.orthonormalized().get_rotation_quaternion().inverse()).normalized()
	if rotation.w < 0.0:
		rotation = -rotation
	var vector := Vector3(rotation.x, rotation.y, rotation.z)
	var magnitude := vector.length()
	return vector * (2.0 * atan2(magnitude, rotation.w) / magnitude) if magnitude > 1.0e-12 else vector * 2.0

static func _constraints(evaluation: Dictionary) -> PackedFloat64Array:
	var values := PackedFloat64Array(evaluation.get("constraints", []))
	var equalities := PackedFloat64Array(evaluation.get("equalities", []))
	var tolerances := PackedFloat64Array(evaluation.get("equality_tolerances", []))
	for i: int in equalities.size():
		var tolerance: float = tolerances[i] if tolerances.size() == equalities.size() else 0.000001
		values.append(equalities[i] - tolerance)
		values.append(-equalities[i] - tolerance)
	return values

static func _search_constraints(evaluation: Dictionary) -> PackedFloat64Array:
	return PackedFloat64Array(evaluation.search_constraints) if evaluation.has("search_constraints") else _constraints(evaluation)

static func _evaluation_valid(evaluation: Dictionary) -> bool:
	if not evaluation.get("valid", false) or not evaluation.get("weapon_frame") is Transform3D:
		return false
	var frame: Transform3D = evaluation.weapon_frame
	if not frame.is_finite() or frame.basis.determinant() <= 0.0:
		return false
	for value: float in _constraints(evaluation):
		if not is_finite(value):
			return false
	for value: float in _search_constraints(evaluation):
		if not is_finite(value):
			return false
	return true

static func _constraint_tolerance(evaluation: Dictionary, index: int) -> float:
	var tolerances := PackedFloat64Array(evaluation.get("constraint_tolerances", []))
	return maxf(CONSTRAINT_EPSILON, tolerances[index]) if index < tolerances.size() else CONSTRAINT_EPSILON

static func _legal(q: PackedFloat64Array, evaluation: Dictionary, lower: PackedFloat64Array, upper: PackedFloat64Array) -> bool:
	for i: int in q.size():
		if not is_finite(q[i]) or q[i] < lower[i] - CONSTRAINT_EPSILON or q[i] > upper[i] + CONSTRAINT_EPSILON:
			return false
	var values := _constraints(evaluation)
	var tolerances := PackedFloat64Array(evaluation.get("constraint_tolerances", []))
	for index: int in values.size():
		var tolerance: float = maxf(CONSTRAINT_EPSILON, tolerances[index]) if index < tolerances.size() else CONSTRAINT_EPSILON
		if values[index] - tolerance > (NUMERIC_EPSILON if tolerance > CONSTRAINT_EPSILON else 0.0):
			return false
	return true

static func _initial_diagnostics(q: PackedFloat64Array, evaluation: Dictionary, lower: PackedFloat64Array, upper: PackedFloat64Array, groups: PackedStringArray) -> Dictionary:
	# Report the same gates used above without changing their acceptance rules.
	# Keep pose payloads out of diagnostics and cap detail for repeated failures.
	var diagnostics := {"evaluation_reason": str(evaluation.get("reason", "")), "evaluation_failures": PackedStringArray(), "scalar_bounds": [], "constraints": [], "scalar_bound_count": 0, "constraint_count": 0, "numeric_tolerance": CONSTRAINT_EPSILON}
	var failures := PackedStringArray()
	if not bool(evaluation.get("valid", false)):
		failures.append("evaluation_valid_false")
	if not evaluation.get("weapon_frame") is Transform3D:
		failures.append("weapon_frame_missing_or_invalid_type")
	else:
		var frame: Transform3D = evaluation.weapon_frame
		if not frame.is_finite():
			failures.append("weapon_frame_nonfinite")
		if frame.basis.determinant() <= 0.0:
			failures.append("weapon_frame_nonpositive_determinant")
	for i: int in q.size():
		if not is_finite(q[i]) or q[i] < lower[i] - CONSTRAINT_EPSILON or q[i] > upper[i] + CONSTRAINT_EPSILON:
			diagnostics.scalar_bound_count += 1
			if diagnostics.scalar_bounds.size() < 8:
				diagnostics.scalar_bounds.append({"index": i, "group": groups[i], "value": q[i], "min": lower[i], "max": upper[i], "tolerance": CONSTRAINT_EPSILON})
	var values := _constraints(evaluation)
	var reasons := PackedStringArray(evaluation.get("constraint_reasons", []))
	var inequality_count := PackedFloat64Array(evaluation.get("constraints", [])).size()
	var equalities := PackedFloat64Array(evaluation.get("equalities", []))
	var equality_tolerances := PackedFloat64Array(evaluation.get("equality_tolerances", []))
	for i: int in values.size():
		if not is_finite(values[i]) or values[i] > _constraint_tolerance(evaluation, i):
			diagnostics.constraint_count += 1
			if not is_finite(values[i]) and "constraint_nonfinite" not in failures:
				failures.append("constraint_nonfinite")
			if diagnostics.constraints.size() < 8:
				var violation := {"index": i, "name": reasons[i] if i < reasons.size() else "COUPLED_LIMIT:" + str(i), "value": values[i], "tolerance": _constraint_tolerance(evaluation, i)}
				if i >= inequality_count:
					var equality_index := int((i - inequality_count) / 2)
					violation.name = "EQUALITY:" + str(equality_index) + (":positive" if (i - inequality_count) % 2 == 0 else ":negative")
					violation.equality_value = equalities[equality_index]
					violation.equality_tolerance = equality_tolerances[equality_index] if equality_tolerances.size() == equalities.size() else 0.000001
				diagnostics.constraints.append(violation)
	diagnostics.evaluation_failures = failures
	return diagnostics

static func _candidate_valid(evaluation: Dictionary, validator: Callable) -> bool:
	if not validator.is_valid():
		return true
	var validation: Dictionary = validator.call(evaluation)
	return bool(validation.get("valid", false))

static func _transition_legal(from: PackedFloat64Array, to: PackedFloat64Array, evaluate: Callable, lower: PackedFloat64Array, upper: PackedFloat64Array, validator: Callable, diagnostics: Dictionary = {}) -> bool:
	for weight: float in [0.25, 0.5, 0.75]:
		var intermediate := from.duplicate()
		for i: int in from.size():
			intermediate[i] = lerpf(from[i], to[i], weight)
		var evaluation: Dictionary = evaluate.call(intermediate)
		if not _evaluation_valid(evaluation) or not _legal(intermediate, evaluation, lower, upper):
			if bool(diagnostics.get("enabled", false)):
				var groups := PackedStringArray()
				groups.resize(intermediate.size())
				diagnostics["stage"] = "intermediate_bounds_or_fk"
				diagnostics["weight"] = weight
				diagnostics["violations"] = _initial_diagnostics(intermediate, evaluation, lower, upper, groups)
				diagnostics["shoulder_states"] = evaluation.get("payload", {}).get("shoulder_states_by_slot", {})
			return false
		if not _candidate_valid(evaluation, validator):
			if bool(diagnostics.get("enabled", false)):
				diagnostics["stage"] = "intermediate_storage_or_collision"
				diagnostics["weight"] = weight
			return false
	return true

static func _contributing_groups(from: PackedFloat64Array, to: PackedFloat64Array, groups: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	for i: int in from.size():
		if absf(from[i] - to[i]) > 0.000001 and groups[i] not in result:
			result.append(groups[i])
	return result

static func _active_limits(q: PackedFloat64Array, lower: PackedFloat64Array, upper: PackedFloat64Array, evaluation: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for i: int in q.size():
		if minf(absf(q[i] - lower[i]), absf(q[i] - upper[i])) < 0.0001:
			result.append("JOINT_RANGE:" + str(i))
	var values := _constraints(evaluation)
	var reasons: PackedStringArray = PackedStringArray(evaluation.get("constraint_reasons", []))
	for i: int in values.size():
		if values[i] >= -0.0001:
			result.append(reasons[i] if i < reasons.size() else "COUPLED_LIMIT:" + str(i))
	return result

static func _zeros(count: int) -> PackedFloat64Array:
	var values := PackedFloat64Array()
	values.resize(count)
	return values

static func _matrix(rows: int, columns: int) -> Array:
	var result: Array = []
	for i: int in rows:
		result.append(_zeros(columns))
	return result

static func _dot(a: PackedFloat64Array, b: PackedFloat64Array) -> float:
	var value := 0.0
	for i: int in a.size():
		value += a[i] * b[i]
	return value

static func _norm_squared(values: PackedFloat64Array) -> float:
	return _dot(values, values)

static func _add(a: PackedFloat64Array, b: PackedFloat64Array, scale: float) -> PackedFloat64Array:
	var result := a.duplicate()
	for i: int in result.size():
		result[i] += b[i] * scale
	return result

static func _gram(rows: Array, count: int) -> Array:
	var result := _matrix(count, count)
	for row: PackedFloat64Array in rows:
		for i: int in count:
			for j: int in count:
				result[i][j] += row[i] * row[j]
	return result

static func _transpose_product(rows: Array, vector: PackedFloat64Array, scale: float) -> PackedFloat64Array:
	var result := _zeros(rows[0].size())
	for row: int in rows.size():
		for column: int in result.size():
			result[column] += rows[row][column] * vector[row] * scale
	return result
