extends SceneTree

## Pure numeric verification; no character pose, geometry, or game state is loaded.
## Known optima and an independent 2D boundary/intersection enumeration verify
## the local QP. This does not certify nonlinear skin collision acceptance.
const Preparation = preload("res://runtime/player/grip/contact_driven_grip_preparation.gd")
var _solver := Preparation.new()
var _checks: Array = []
var _cases: Array = []
var _failed: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_case("one_lower_bound", [[1.0]], [0.0], [_bound([1.0], 1.0)], [1.0])
	_case("inactive_lower_bound", [[1.0]], [2.0], [_bound([1.0], 1.0)], [2.0])
	_case("negative_direction_upper_bound", [[1.0]], [3.0], [_bound([-1.0], -1.0)], [1.0])
	_case("unconstrained_coupled", [[2.0,1.0],[1.0,2.0]], [3.0,0.0], [], [2.0,-1.0])
	_case("diagonal_contact", [[1.0,0.0],[0.0,1.0]], [0.0,0.0], [_bound([1.0,1.0],2.0)], [1.0,1.0])
	_case("weighted_diagonal_contact", [[2.0,0.0],[0.0,1.0]], [0.0,0.0], [_bound([1.0,1.0],3.0)], [1.0,2.0])
	_case("two_independent_bounds", [[1.0,0.0],[0.0,1.0]], [0.0,0.0], [_bound([1.0,0.0],1.0),_bound([0.0,1.0],2.0)], [1.0,2.0])
	_case("release_old_boundary", [[1.0,0.0],[0.0,1.0]], [0.0,0.0], [_bound([1.0,0.0],1.0),_bound([1.0,1.0],3.0)], [1.5,1.5], true, true)
	_case("stronger_duplicate_releases", [[1.0]], [0.0], [_bound([1.0],1.0),_bound([1.0],2.0)], [2.0], true, true)
	_case("weaker_duplicate_redundant", [[1.0]], [0.0], [_bound([1.0],2.0),_bound([1.0],1.0),_bound([2.0],4.0)], [2.0])
	_case("zero_rows_redundant", [[1.0]], [2.0], [_bound([0.0],-1.0),_bound([0.0],0.0)], [2.0])
	_case("tiny_constraint_units", [[1.0]], [0.0], [_bound([1.0e-200],2.0e-200)], [2.0])
	_case("large_constraint_units", [[1.0]], [0.0], [_bound([1.0e150],2.0e150)], [2.0])
	_case("tiny_objective_units", [[1.0e-12]], [3.0e-12], [_bound([-0.003],-0.003)], [1.0])
	_case("large_objective_units", [[1.0e12]], [3.0e12], [_bound([-0.003],-0.003)], [1.0])
	_case("one_contact_cap_leaves_other_dof", [[2.0,1.0],[1.0,2.0]], [3.0,2.0], [_bound([-0.005,0.0],0.0)], [0.0,1.0])
	_case("contact_cap_and_trust_boundary", [[2.0,1.0],[1.0,2.0]], [3.0,4.0], [_bound([-0.005,0.0],0.0),_bound([0.0,-1.0],-1.0)], [0.0,1.0])
	_case("slide_along_oblique_zero_cap", [[1.0,0.0],[0.0,1.0]], [3.0,2.0], [_bound([-0.003,-0.003],0.0)], [0.5,-0.5])
	_case("equality_as_opposite_bounds", [[1.0,0.0],[0.0,1.0]], [0.0,0.0], [_bound([1.0,0.0],1.0),_bound([-1.0,0.0],-1.0),_bound([0.0,1.0],2.0)], [1.0,2.0])
	var identity: Array = []
	var trust: Array = []
	for axis: int in 5:
		var row: Array = []
		for column: int in 5: row.append(1.0 if axis == column else 0.0)
		identity.append(row)
		trust.append(_bound(row.duplicate(),-1.0))
		var opposite: Array = row.duplicate()
		opposite[axis] = -1.0
		trust.append(_bound(opposite,-1.0))
	_case("five_dof_trust_box", identity, [2.0,-1.0,3.0,0.0,5.0], trust, [1.0,-1.0,1.0,0.0,1.0])
	_case("infeasible_opposite_bounds", [[1.0]], [0.0], [_bound([1.0],1.0),_bound([-1.0],0.0)], [], false)
	_case("infeasible_dependent_triangle", [[1.0,0.0],[0.0,1.0]], [0.0,0.0], [_bound([1.0,0.0],0.0),_bound([0.0,1.0],0.0),_bound([-1.0,-1.0],1.0)], [], false)
	_case("infeasible_zero_row", [[1.0]], [0.0], [_bound([0.0],1.0)], [], false)
	_case("indefinite_objective", [[1.0,2.0],[2.0,1.0]], [0.0,0.0], [], [], false)
	_case("singular_objective", [[1.0,1.0],[1.0,1.0]], [0.0,0.0], [], [], false)
	_case("asymmetric_objective", [[1.0,0.0],[1.0,1.0]], [0.0,0.0], [], [], false)
	_case("invalid_constraint_size", [[1.0]], [0.0], [_bound([1.0,0.0],0.0)], [], false)
	_case("nonfinite_rhs", [[1.0]], [NAN], [], [], false)
	_case("nonfinite_constraint", [[1.0]], [0.0], [_bound([INF],0.0)], [], false)
	# Bounded 2D oracle enumerates every possible optimum: free, on one line,
	# or at a pair of line intersections. It does not use the tested linear solver.
	for sample: int in 12:
		var hessian: Array = [[2.0+0.1*sample,0.3],[0.3,1.0+0.2*sample]]
		var rhs: Array = [3.0*cos(0.7*sample),2.0*sin(0.9*sample)]
		var constraints: Array = [_bound([1.0,0.0],-0.7),_bound([-1.0,0.0],-1.0),
			_bound([0.0,1.0],-0.8),_bound([0.0,-1.0],-0.9),_bound([0.6,0.8],-0.1),
			_bound([-0.8,0.6],-0.2)]
		var expected: Array = _enumerated_optimum_2d(hessian,rhs,constraints)
		_check(not expected.is_empty(),"independent 2D oracle has feasible candidate " + str(sample))
		if expected.is_empty(): continue
		_case("enumerated_2d_" + str(sample),hessian,rhs,constraints,expected)
		constraints.reverse()
		_case("reversed_2d_" + str(sample),hessian,rhs,constraints,expected)
	var prefix: String = "C:/WORKSPACE/test_artifacts/contact_constraint_step_" + Time.get_datetime_string_from_system().replace(":","-")
	var report := {"passed":_failed == 0,"checks":_checks,"cases":_cases,
		"scope":"local convex contact-step inequalities only; no nonlinear skin collision or live grip claim"}
	var file := FileAccess.open(prefix + ".json",FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	else:
		_check(false,"write numerical verification report")
	print("CONTACT_CONSTRAINT_STEP ","PASS" if _failed == 0 else "FAIL"," checks=",_checks.size()," cases=",_cases.size()," failures=",_failed," report=",prefix + ".json")
	quit(0 if _failed == 0 else 1)


func _bound(gradient: Array, minimum: float) -> Dictionary:
	return {"gradient":gradient,"minimum":minimum}


func _case(label: String, matrix: Array, rhs: Array, constraints: Array, expected: Array,
		should_solve: bool = true, require_release: bool = false) -> void:
	var before: PackedByteArray = var_to_bytes([matrix,rhs,constraints])
	var result: Dictionary = _solver._constrained_linear(matrix,rhs,constraints)
	_cases.append({"name":label,"expected":expected,"result":result})
	_check(var_to_bytes([matrix,rhs,constraints]) == before,label + ": input equations immutable")
	_check(result.get("valid",false) == should_solve,label + ": validity")
	_check(result.get("active_indices",[]).size() <= rhs.size(),label + ": active count bounded by DOF")
	if not should_solve:
		_check(not result.get("reason","").is_empty() and result.get("delta",[]).is_empty(),label + ": honest failure without usable step")
		return
	if not result.get("valid",false): return
	var delta: Array = result.delta
	_check(delta.size() == expected.size(),label + ": expected dimensions")
	if delta.size() != expected.size(): return
	for axis: int in expected.size():
		_check(is_finite(delta[axis]) and absf(delta[axis]-expected[axis]) <= 1.0e-7 * (1.0+absf(expected[axis])),label + ": known optimum axis " + str(axis))
	for index: int in constraints.size():
		var constraint: Dictionary = constraints[index]
		var achieved: float = 0.0
		var scale: float = absf(constraint.minimum)
		for axis: int in delta.size():
			achieved += constraint.gradient[axis] * delta[axis]
			scale = maxf(scale,absf(constraint.gradient[axis]))
		_check(achieved >= constraint.minimum - 1.0e-8 * scale,label + ": independently feasible row " + str(index))
	var seen: Dictionary = {}
	for index: int in result.active_indices:
		_check(index >= 0 and index < constraints.size() and not seen.has(index),label + ": unique original active index")
		seen[index] = true
	if require_release: _check(result.get("releases",0) > 0,label + ": former active multiplier released")


func _enumerated_optimum_2d(hessian: Array, rhs: Array, constraints: Array) -> Array:
	var determinant: float = hessian[0][0]*hessian[1][1]-hessian[0][1]*hessian[1][0]
	var inverse: Array = [[hessian[1][1]/determinant,-hessian[0][1]/determinant],
		[-hessian[1][0]/determinant,hessian[0][0]/determinant]]
	var free: Array = [inverse[0][0]*rhs[0]+inverse[0][1]*rhs[1],inverse[1][0]*rhs[0]+inverse[1][1]*rhs[1]]
	var candidates: Array = [free]
	for first: int in constraints.size():
		var a: Array = constraints[first].gradient
		var inverse_a: Array = [inverse[0][0]*a[0]+inverse[0][1]*a[1],inverse[1][0]*a[0]+inverse[1][1]*a[1]]
		var offset: float = (constraints[first].minimum-a[0]*free[0]-a[1]*free[1])/(a[0]*inverse_a[0]+a[1]*inverse_a[1])
		candidates.append([free[0]+offset*inverse_a[0],free[1]+offset*inverse_a[1]])
		for second: int in range(first+1,constraints.size()):
			var b: Array = constraints[second].gradient
			var det: float = a[0]*b[1]-a[1]*b[0]
			if absf(det) < 1.0e-12: continue
			candidates.append([(constraints[first].minimum*b[1]-a[1]*constraints[second].minimum)/det,
				(a[0]*constraints[second].minimum-constraints[first].minimum*b[0])/det])
	var best: Array = []
	var best_cost: float = INF
	for candidate: Array in candidates:
		var feasible: bool = true
		for constraint: Dictionary in constraints:
			if constraint.gradient[0]*candidate[0]+constraint.gradient[1]*candidate[1] < constraint.minimum-1.0e-9:
				feasible = false
		if not feasible: continue
		var cost: float = 0.5 * (candidate[0]*(hessian[0][0]*candidate[0]+hessian[0][1]*candidate[1])
			+candidate[1]*(hessian[1][0]*candidate[0]+hessian[1][1]*candidate[1]))-rhs[0]*candidate[0]-rhs[1]*candidate[1]
		if cost < best_cost:
			best_cost = cost
			best = candidate
	return best


func _check(condition: bool, label: String) -> void:
	_checks.append({"passed":condition,"label":label})
	if not condition:
		_failed += 1
		push_error(label)
