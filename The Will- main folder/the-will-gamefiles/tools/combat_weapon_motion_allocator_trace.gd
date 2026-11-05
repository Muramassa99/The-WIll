extends RefCounted
class_name CombatWeaponMotionAllocatorTrace

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
## Roll alone retains a world contact_anchor in the SAME origin_id as the
## weapon frames. Omitting it starts Roll at the previous contact position.

## Diagnostic-only frozen copy of core/resolvers/combat_weapon_motion_allocator.gd.
## Never used by production. The original calculations and acceptance rules are
## preserved; trace recording adds overhead, so timings are not benchmarks.
static var probe_trace: Array[Dictionary] = []
static var probe_trace_limit: int = 12000
static var probe_dropped_events: int = 0
static var probe_fit_sequence: int = 0
static var probe_active_fit: int = 0

static func begin_probe(limit: int = 12000) -> void:
	probe_trace.clear()
	probe_trace_limit = maxi(1, limit)
	probe_dropped_events = 0
	probe_fit_sequence = 0
	probe_active_fit = 0

static func _probe_record(kind: String, fields: Dictionary) -> void:
	if probe_trace.size() >= probe_trace_limit:
		probe_dropped_events += 1
		return
	var entry := fields.duplicate(true)
	entry["event"] = kind
	entry["fit"] = probe_active_fit
	probe_trace.append(entry)

static func _probe_evaluation(evaluation: Dictionary) -> Dictionary:
	return {"valid": _evaluation_valid(evaluation),
		"constraints": _constraints(evaluation),
		"constraint_reasons": evaluation.get("constraint_reasons", []),
		"search_constraints": _search_constraints(evaluation),
		"search_constraint_reasons": evaluation.get("search_constraint_reasons", []),
		"weapon_frame": evaluation.get("weapon_frame", Transform3D.IDENTITY)}

const PolicyDef = preload("res://core/defs/weapon_motion_policy_def.gd")
const REVISION := "weapon_motion_allocation_v1"
const NUMERIC_EPSILON := 1.0e-8
const CONSTRAINT_EPSILON := 1.0e-6
const PIVOT_EPSILON := 1.0e-10
const QP_ITERATIONS := 80

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
	if mode not in ["tip", "pommel", "roll"] or not input.get("target_weapon") is Transform3D or not input.get("contact_local") is Vector3:
		return result
	var target: Transform3D = input.target_weapon
	var contact: Vector3 = input.contact_local
	if not previous.is_finite() or not target.is_finite() or not contact.is_finite() or previous.basis.determinant() <= 0.0 or target.basis.determinant() <= 0.0:
		return result
	var anchor: Vector3 = previous * contact
	if mode == "roll" and input.has("contact_anchor"):
		if not input.contact_anchor is Vector3 or not (input.contact_anchor as Vector3).is_finite():
			result.reason = "allocator_contact_anchor_invalid"
			return result
		anchor = input.contact_anchor
	_probe_record("solve_input", {"q": q, "lower": lower, "upper": upper, "groups": groups, "previous_weapon": previous, "target_weapon": target, "mode": mode, "policy": policy})
	var initial: Dictionary = evaluate.call(q)
	var initial_validation := validate_initial_pose(input, initial, policy)
	if not initial_validation.valid:
		result.merge(initial_validation, true)
		return result
	var start_allowance := build_start_allowance(input, initial)
	_probe_record("start_allowance", {"allowance": start_allowance, "evaluation": _probe_evaluation(initial)})
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
	if mode == "pommel":
		if _rotation_vector(target.basis, previous.basis).length() > float(policy.orientation_tolerance):
			result.reason = "allocator_translation_changed_orientation"
			return result
	elif mode == "roll" and (target * contact).distance_to(anchor) > float(policy.position_tolerance):
		result.reason = "allocator_rotation_changed_contact_anchor"
		return result
	var angle := _rotation_vector(target.basis, previous.basis).length()
	var distance := 0.0 if mode == "tip" else (target * contact).distance_to(previous * contact)
	var count := maxi(1, int(ceil(maxf(angle / float(policy.max_rotation_step), distance / float(policy.max_translation_step)))))
	var accepted_fraction := 0.0
	var accepted_eval := initial
	var attempted_failure := ""
	result["search_failures"] = []
	var max_substeps := maxi(1, int(policy.max_substeps))
	for step: int in mini(count, max_substeps):
		var requested_fraction := float(step + 1) / float(count)
		var requested := _target_at(previous, target, contact, mode, requested_fraction, anchor)
		var attempted := _fit(q, requested, contact, groups, lower, upper, input, permitted_evaluate, policy)
		result.iterations += int(attempted.iterations)
		if attempted.valid:
			q = attempted.q
			accepted_eval = attempted.evaluation
			accepted_fraction = requested_fraction
			continue
		attempted_failure = attempted.reason
		result.search_failures.append(_attempt_diagnostics(attempted, requested_fraction))
		# Common task scaling preserves the commanded path. Never scale the
		# joint vector and claim the nonlinear contact stayed fixed.
		var low := accepted_fraction
		var high := requested_fraction
		var start_q := q.duplicate()
		for search: int in maxi(0, int(policy.scale_search_steps)):
			var middle := (low + high) * 0.5
			var smaller := _fit(start_q, _target_at(previous, target, contact, mode, middle, anchor), contact, groups, lower, upper, input, permitted_evaluate, policy)
			result.iterations += int(smaller.iterations)
			if smaller.valid:
				low = middle
				q = smaller.q
				accepted_eval = smaller.evaluation
			else:
				high = middle
				if result.search_failures.size() < 8:
					result.search_failures.append(_attempt_diagnostics(smaller, middle))
		accepted_fraction = low
		break
	var requested_error := _pose_error(previous, target, contact)
	if q == PackedFloat64Array(input.q) and ((mode != "tip" and requested_error.position > float(policy.position_tolerance)) or requested_error.angle > float(policy.orientation_tolerance)):
		# Scaling a real command down inside the fit tolerance is not movement.
		# Report no progress instead of certifying an unchanged joint packet.
		accepted_fraction = 0.0
		attempted_failure = "allocator_no_task_progress"
	result.accepted_q = q
	result.accepted_weapon = accepted_eval.weapon_frame
	result.accepted_payload = accepted_eval.get("payload", {})
	result.task_scale = accepted_fraction
	result.valid = accepted_fraction > NUMERIC_EPSILON
	result.status = "ACCEPTED" if accepted_fraction >= 1.0 - NUMERIC_EPSILON else ("SCALED" if result.valid else "SEARCH_EXHAUSTED")
	result.reason = "" if result.status == "ACCEPTED" else (attempted_failure if not attempted_failure.is_empty() else "allocator_substep_budget")
	var accepted_target := _target_at(previous, target, contact, mode, accepted_fraction, anchor)
	var errors := _pose_error(accepted_eval.weapon_frame, accepted_target, contact)
	# Keep physical displacement visible without turning Tip translation into
	# a task or pivot-lock condition. Accepted_weapon is always actual joint FK.
	result.pivot_error = errors.position
	result.position_constrained = mode != "tip"
	result.contact_displacement = ((accepted_eval.weapon_frame as Transform3D) * contact).distance_to(previous * contact)
	result.contact_anchor = anchor if mode == "roll" else (accepted_eval.weapon_frame as Transform3D) * contact
	result.contact_anchor_origin_id = input.origin_id
	result.orientation_error = errors.angle
	result.remaining_task_error = _pose_error(accepted_eval.weapon_frame, target, contact)
	if mode == "tip":
		result.remaining_task_error.position = 0.0
	result.contributing_joint_groups = _contributing_groups(PackedFloat64Array(input.q), q, groups)
	var actual_evaluation: Dictionary = evaluate.call(q)
	var original_lower := PackedFloat64Array(input.lower)
	var original_upper := PackedFloat64Array(input.upper)
	result.pose_warning = _pose_warning(q, actual_evaluation, original_lower, original_upper, groups)
	result.active_limits = _active_limits(q, original_lower, original_upper, actual_evaluation)
	return result

static func _attempt_diagnostics(attempt: Dictionary, fraction: float) -> Dictionary:
	return {"fraction": fraction, "reason": attempt.reason, "iterations": attempt.iterations,
		"qp": attempt.get("qp_diagnostics", {})}

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
			offsets[names[i]] = values[i]
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
	return name.begins_with("JOINT_RANGE:") or name.begins_with("COUPLED_LIMIT:")

static func _pose_warning(q: PackedFloat64Array, evaluation: Dictionary, lower: PackedFloat64Array, upper: PackedFloat64Array, groups: PackedStringArray) -> Dictionary:
	return {} if _evaluation_valid(evaluation) and _legal(q, evaluation, lower, upper) else _initial_diagnostics(q, evaluation, lower, upper, groups)

static func _fit(start: PackedFloat64Array, target: Transform3D, contact: Vector3, groups: PackedStringArray, lower: PackedFloat64Array, upper: PackedFloat64Array, input: Dictionary, evaluate: Callable, policy: Dictionary) -> Dictionary:
	probe_fit_sequence += 1
	probe_active_fit = probe_fit_sequence
	_probe_record("fit_start", {"start": start, "target": target})
	var q := start.duplicate()
	var evaluation: Dictionary = evaluate.call(q)
	var validator: Callable = input.get("validate_candidate", Callable())
	var mode := String(input.mode)
	var response := {"valid": false, "q": start, "evaluation": evaluation, "iterations": 0, "reason": "allocator_search_exhausted"}
	for iteration: int in maxi(1, int(policy.max_iterations)):
		response.iterations = iteration + 1
		var error := _pose_error(evaluation.weapon_frame, target, contact)
		_probe_record("iteration", {"iteration": iteration, "q": q, "error": error, "evaluation": _probe_evaluation(evaluation)})
		if _legal(q, evaluation, lower, upper) and (mode == "tip" or error.position <= float(policy.position_tolerance)) and error.angle <= float(policy.orientation_tolerance):
			if not _candidate_valid(evaluation, validator):
				response.reason = "allocator_candidate_collision_or_context_invalid"
				_probe_record("fit_end", {"valid": response.valid, "reason": response.reason, "iterations": response.iterations, "final_q": q, "final_error": _pose_error(evaluation.weapon_frame, target, contact), "final_evaluation": _probe_evaluation(evaluation)})
				return response
			response.valid = true
			response.q = q
			response.evaluation = evaluation
			_probe_record("fit_end", {"valid": response.valid, "reason": response.reason, "iterations": response.iterations, "final_q": q, "final_error": _pose_error(evaluation.weapon_frame, target, contact), "final_evaluation": _probe_evaluation(evaluation)})
			return response
		var differential := _differentiate(q, evaluation, contact, evaluate, policy, mode)
		if not differential.valid:
			response.reason = "allocator_invalid_forward_sample"
			_probe_record("fit_end", {"valid": response.valid, "reason": response.reason, "iterations": response.iterations, "final_q": q, "final_error": _pose_error(evaluation.weapon_frame, target, contact), "final_evaluation": _probe_evaluation(evaluation)})
			return response
		var jacobian: Array = differential.jacobian
		var residual := _task_vector(evaluation.weapon_frame, target, contact, float(policy.position_normalization), mode)
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
		_probe_record("task_qp", {"iteration": iteration, "result": optimized, "jacobian": jacobian, "residual": residual})
		if not optimized.valid:
			response.reason = "allocator_qp_search_exhausted"
			response["qp_diagnostics"] = {"stage": "task", "reason": optimized.get("reason", ""), "active": optimized.get("active", []), "trace": optimized.get("trace", [])}
			_probe_record("fit_end", {"valid": response.valid, "reason": response.reason, "iterations": response.iterations, "final_q": q, "final_error": _pose_error(evaluation.weapon_frame, target, contact), "final_evaluation": _probe_evaluation(evaluation)})
			return response
		var delta: PackedFloat64Array = optimized.x
		# Each lower-priority QP preserves the already achieved higher-priority
		# task exactly. No huge finite weights masquerading as strict priority.
		var equalities: Array = jacobian.duplicate()
		for tier: PackedStringArray in _hold_order(str(input.mode), policy):
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
			_probe_record("priority_qp", {"iteration": iteration, "tier": tier, "incoming_delta": delta, "result": preferred})
			if not preferred.valid:
				response.reason = "allocator_priority_search_exhausted"
				response["qp_diagnostics"] = {"stage": "priority", "tier": tier, "reason": preferred.get("reason", ""), "active": preferred.get("active", []), "trace": preferred.get("trace", [])}
				_probe_record("fit_end", {"valid": response.valid, "reason": response.reason, "iterations": response.iterations, "final_q": q, "final_error": _pose_error(evaluation.weapon_frame, target, contact), "final_evaluation": _probe_evaluation(evaluation)})
				return response
			delta = preferred.x
			for i: int in indices:
				var row := _zeros(q.size())
				row[i] = 1.0
				equalities.append(row)
		if _norm_squared(delta) < 1.0e-16:
			response.reason = "allocator_no_local_progress"
			_probe_record("fit_end", {"valid": response.valid, "reason": response.reason, "iterations": response.iterations, "final_q": q, "final_error": _pose_error(evaluation.weapon_frame, target, contact), "final_evaluation": _probe_evaluation(evaluation)})
			return response
		_probe_record("chosen_delta", {"iteration": iteration, "delta": delta})
		var old_error := _norm_squared(residual)
		var advanced := false
		var fraction := 1.0
		for line_search: int in 10:
			var trial := _add(q, delta, fraction)
			var trial_eval: Dictionary = evaluate.call(trial)
			if _evaluation_valid(trial_eval) and not _legal(trial, trial_eval, lower, upper):
				var restored := _restore_feasible(trial, trial_eval, evaluate, lower, upper, policy)
				trial = restored.q
				trial_eval = restored.evaluation
			_probe_record("line_search", {"iteration": iteration, "line_search": line_search, "fraction": fraction, "trial_q": trial, "error": _pose_error(trial_eval.weapon_frame, target, contact) if _evaluation_valid(trial_eval) else {}, "evaluation": _probe_evaluation(trial_eval)})
			if _evaluation_valid(trial_eval) and _legal(trial, trial_eval, lower, upper):
				var next_error := _norm_squared(_task_vector(trial_eval.weapon_frame, target, contact, float(policy.position_normalization), mode))
				if next_error < old_error - 1.0e-16 and _candidate_valid(trial_eval, validator) and _transition_legal(q, trial, evaluate, lower, upper, validator):
					_probe_record("advance", {"iteration": iteration, "fraction": fraction, "q": trial, "old_error_squared": old_error, "next_error_squared": next_error})
					q = trial
					evaluation = trial_eval
					advanced = true
					break
			fraction *= 0.5
		if not advanced:
			response.reason = "allocator_nonlinear_step_blocked"
			_probe_record("fit_end", {"valid": response.valid, "reason": response.reason, "iterations": response.iterations, "final_q": q, "final_error": _pose_error(evaluation.weapon_frame, target, contact), "final_evaluation": _probe_evaluation(evaluation)})
			return response
	_probe_record("fit_end", {"valid": response.valid, "reason": response.reason, "iterations": response.iterations, "final_q": q, "final_error": _pose_error(evaluation.weapon_frame, target, contact), "final_evaluation": _probe_evaluation(evaluation)})
	return response

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
			if values[row] > excess:
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

static func _differentiate(q: PackedFloat64Array, evaluation: Dictionary, contact: Vector3, evaluate: Callable, policy: Dictionary, mode: String = "") -> Dictionary:
	var base_constraints := _search_constraints(evaluation)
	var custom_search: bool = evaluation.has("search_constraints")
	var task_rows := 3 if mode == "tip" else 6
	var j := _matrix(task_rows, q.size())
	var c := _matrix(base_constraints.size(), q.size())
	var epsilon := float(policy.finite_difference)
	for column: int in q.size():
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
		for row: int in values.size():
			# Custom search rows have their own indexing. Physical norm metadata
			# must never be applied to a search slab at the same numeric index.
			c[row][column] = (values[row] - base_constraints[row]) / epsilon if custom_search else _constraint_slope(evaluation, sample, row, base_constraints[row], values[row], epsilon)
	return {"valid": true, "jacobian": j, "constraints": c}

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
	var x := initial.duplicate()
	var active := PackedInt32Array()
	var trace: Array[Dictionary] = []
	for i: int in inequalities.size():
		if _dot(inequalities[i], x) > limits[i] + CONSTRAINT_EPSILON:
			return {"valid": false, "x": initial, "reason": "infeasible_start", "active": [i]}
	for iteration: int in QP_ITERATIONS:
		var rows: Array = equalities.duplicate()
		for index: int in active:
			rows.append(inequalities[index])
		var dimension := x.size() + rows.size()
		var system := _matrix(dimension, dimension)
		var rhs := _zeros(dimension)
		var row_scales := PackedFloat64Array()
		for i: int in x.size():
			for k: int in x.size():
				system[i][k] = h[i][k]
			rhs[i] = -g[i] - _dot(h[i], x)
		for row: int in rows.size():
			# Contact derivatives are in normalized micrometre/radian units while
			# joint bounds have unit normals. Normalize only the KKT equations to
			# avoid conditioning loss; original bounds and line search stay intact.
			var row_norm := sqrt(_norm_squared(rows[row]))
			var row_scale := row_norm if row_norm > PIVOT_EPSILON else 1.0
			row_scales.append(row_scale)
			for column: int in x.size():
				system[x.size() + row][column] = rows[row][column] / row_scale
				system[column][x.size() + row] = rows[row][column] / row_scale
		var solved := _linear_solve(system, rhs)
		if not solved.valid:
			return {"valid": false, "x": x, "reason": "inconsistent_linear_system", "active": active, "trace": trace}
		var solution: PackedFloat64Array = solved.x
		var direction := solution.slice(0, x.size())
		var step_trace := {"iteration": iteration, "active": active.duplicate(), "direction_squared": _norm_squared(direction)}
		if _norm_squared(direction) <= 1.0e-18:
			var remove := -1
			var minimum := -1.0e-8
			for i: int in active.size():
				var multiplier := solution[x.size() + equalities.size() + i] / row_scales[equalities.size() + i]
				if multiplier < minimum:
					minimum = multiplier
					remove = i
			if remove < 0:
				return {"valid": true, "x": x}
			step_trace["remove"] = active[remove]
			trace.append(step_trace)
			if trace.size() > 8:
				trace.pop_front()
			active.remove_at(remove)
			continue
		var fraction := 1.0
		var blocker := -1
		for i: int in inequalities.size():
			if i in active:
				continue
			var travel := _dot(inequalities[i], direction)
			if travel <= PIVOT_EPSILON:
				continue
			var available := maxf(0.0, limits[i] - _dot(inequalities[i], x)) / travel
			if available < fraction:
				fraction = available
				blocker = i
		x = _add(x, direction, fraction)
		step_trace["fraction"] = fraction
		step_trace["blocker"] = blocker
		trace.append(step_trace)
		if trace.size() > 8:
			trace.pop_front()
		if blocker >= 0:
			active.append(blocker)
	return {"valid": false, "x": x, "reason": "iteration_budget", "active": active, "trace": trace}

static func _linear_solve(matrix: Array, rhs: PackedFloat64Array) -> Dictionary:
	var count := rhs.size()
	var a: Array = []
	for i: int in count:
		var row: PackedFloat64Array = matrix[i].duplicate()
		row.append(rhs[i])
		a.append(row)
	var pivots := PackedInt32Array()
	var rank := 0
	for column: int in count:
		var pivot := rank
		for row: int in range(rank, count):
			if absf(a[row][column]) > absf(a[pivot][column]):
				pivot = row
		if absf(a[pivot][column]) <= PIVOT_EPSILON:
			continue
		var swap: PackedFloat64Array = a[rank]
		a[rank] = a[pivot]
		a[pivot] = swap
		var divisor: float = a[rank][column]
		for k: int in range(column, count + 1):
			a[rank][k] /= divisor
		for row: int in count:
			if row == rank:
				continue
			var factor: float = a[row][column]
			if absf(factor) <= PIVOT_EPSILON:
				continue
			for k: int in range(column, count + 1):
				a[row][k] -= factor * a[rank][k]
		pivots.append(column)
		rank += 1
		if rank == count:
			break
	for row: int in range(rank, count):
		if absf(a[row][count]) > 1.0e-7:
			return {"valid": false}
	var answer := _zeros(count)
	for row: int in rank:
		answer[pivots[row]] = a[row][count]
	return {"valid": true, "x": answer}

static func _hold_order(mode: String, policy: Dictionary) -> Array:
	if policy.get("hold_order_by_mode", {}).has(mode):
		return policy.hold_order_by_mode[mode]
	# Ordered minimization is the reverse of preferred contribution. These
	# groups remain available for necessary geometric compensation at every step.
	if mode == "pommel":
		return [PackedStringArray(["torso"]), PackedStringArray(["girdle", "shoulder_girdle"]), PackedStringArray(["wrist", "forearm"]), PackedStringArray(["shoulder", "shoulder_swing", "shoulder_roll", "elbow"])]
	if mode == "roll":
		return [PackedStringArray(["torso"]), PackedStringArray(["girdle", "shoulder_girdle"]), PackedStringArray(["shoulder", "shoulder_roll"]), PackedStringArray(["wrist", "elbow", "shoulder_swing"]), PackedStringArray(["forearm"])]
	return [PackedStringArray(["torso"]), PackedStringArray(["girdle", "shoulder_girdle"]), PackedStringArray(["shoulder", "shoulder_swing", "shoulder_roll"]), PackedStringArray(["forearm"]), PackedStringArray(["elbow"]), PackedStringArray(["wrist"])]

static func _target_at(previous: Transform3D, target: Transform3D, contact: Vector3, mode: String, weight: float, anchor: Vector3) -> Transform3D:
	if mode == "pommel":
		return Transform3D(previous.basis, previous.origin.lerp(target.origin, weight))
	var rotation := previous.basis.orthonormalized().get_rotation_quaternion().slerp(target.basis.orthonormalized().get_rotation_quaternion(), weight)
	var basis := Basis(rotation).scaled(previous.basis.get_scale())
	if mode == "tip":
		# This origin is descriptive only. Tip's residual/Jacobian contain no
		# translation rows; no weapon point is pinned in space by this target.
		return Transform3D(basis, previous.origin.lerp(target.origin, weight))
	return Transform3D(basis, anchor - basis * contact)

static func _pose_error(current: Transform3D, target: Transform3D, contact: Vector3) -> Dictionary:
	return {"position": (current * contact).distance_to(target * contact), "angle": _rotation_vector(target.basis, current.basis).length()}

static func _task_vector(current: Transform3D, target: Transform3D, contact: Vector3, length_scale: float, mode: String = "") -> PackedFloat64Array:
	var angular := _rotation_vector(target.basis, current.basis)
	if mode == "tip":
		return PackedFloat64Array([angular.x, angular.y, angular.z])
	var position := (target * contact - current * contact) / length_scale
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

static func _legal(q: PackedFloat64Array, evaluation: Dictionary, lower: PackedFloat64Array, upper: PackedFloat64Array) -> bool:
	for i: int in q.size():
		if not is_finite(q[i]) or q[i] < lower[i] - CONSTRAINT_EPSILON or q[i] > upper[i] + CONSTRAINT_EPSILON:
			return false
	for value: float in _constraints(evaluation):
		if value > CONSTRAINT_EPSILON:
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
		if not is_finite(values[i]) or values[i] > CONSTRAINT_EPSILON:
			diagnostics.constraint_count += 1
			if not is_finite(values[i]) and "constraint_nonfinite" not in failures:
				failures.append("constraint_nonfinite")
			if diagnostics.constraints.size() < 8:
				var violation := {"index": i, "name": reasons[i] if i < reasons.size() else "COUPLED_LIMIT:" + str(i), "value": values[i], "tolerance": CONSTRAINT_EPSILON}
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
	if not bool(validation.get("valid", false)):
		_probe_record("candidate_rejected", {"validation": validation, "evaluation": _probe_evaluation(evaluation)})
	return bool(validation.get("valid", false))

static func _transition_legal(from: PackedFloat64Array, to: PackedFloat64Array, evaluate: Callable, lower: PackedFloat64Array, upper: PackedFloat64Array, validator: Callable) -> bool:
	for weight: float in [0.25, 0.5, 0.75]:
		var intermediate := from.duplicate()
		for i: int in from.size():
			intermediate[i] = lerpf(from[i], to[i], weight)
		var evaluation: Dictionary = evaluate.call(intermediate)
		if not _evaluation_valid(evaluation) or not _legal(intermediate, evaluation, lower, upper) or not _candidate_valid(evaluation, validator):
			_probe_record("transition_rejected", {"weight": weight, "q": intermediate, "evaluation": _probe_evaluation(evaluation)})
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
