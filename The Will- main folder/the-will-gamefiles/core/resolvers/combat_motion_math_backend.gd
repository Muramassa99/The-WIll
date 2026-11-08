extends RefCounted
class_name CombatMotionMathBackend

## Numerical backend only. FK inputs retain caller-owned parent-bone-local
## transforms and ancestry; no roots, limits, grip state or poses are inferred.
## QP is the Stable-body active-set/rank-elimination calculation, in double.
## Native failures remain failures. Only an unavailable native class falls back.
const CONSTRAINT_EPSILON := 1.0e-6
const PIVOT_EPSILON := 1.0e-10
const QP_ITERATIONS := 80
static var _native_enabled := true
static var _native_checked := false
static var _native_kernel: RefCounted
static var _profiling_enabled := false
static var _stats: Dictionary = {
	"native_qp_calls": 0, "reference_qp_calls": 0,
	"native_forward_calls": 0, "reference_forward_calls": 0,
	"unavailable_fallback_calls": 0, "qp_us": 0, "forward_us": 0,
}

static func configure_native(enabled: bool) -> void:
	_native_enabled = enabled
	_native_checked = false
	_native_kernel = null

static func configure_profiling(enabled: bool) -> void:
	_profiling_enabled = enabled

static func reset_backend_stats() -> void:
	for key: String in _stats:
		_stats[key] = 0

static func get_backend_stats() -> Dictionary:
	return _stats.merged({"native_enabled": _native_enabled,
		"native_available": _native_kernel != null, "profiling_enabled": _profiling_enabled})

static func _ensure_native_kernel() -> bool:
	if not _native_enabled:
		return false
	if not _native_checked:
		_native_checked = true
		if ClassDB.class_exists(&"CombatMotionMathKernel"):
			_native_kernel = ClassDB.instantiate(&"CombatMotionMathKernel") as RefCounted
		if _native_kernel == null:
			push_warning("Combat motion math native kernel unavailable; using the GDScript numerical reference.")
	return _native_kernel != null

static func qp(h: Array, g: PackedFloat64Array, equalities: Array, inequalities: Array,
		limits: PackedFloat64Array, initial: PackedFloat64Array) -> Dictionary:
	var started: int = Time.get_ticks_usec() if _profiling_enabled else 0
	var result: Dictionary
	if _ensure_native_kernel():
		_stats.native_qp_calls += 1
		result = _native_kernel.call("solve_qp", h, g, equalities, inequalities, limits, initial)
	else:
		_stats.reference_qp_calls += 1
		_stats.unavailable_fallback_calls += 1 if _native_enabled else 0
		result = qp_reference(h, g, equalities, inequalities, limits, initial)
	if _profiling_enabled:
		_stats.qp_us += Time.get_ticks_usec() - started
	return result

static func forward(poses: Array[Transform3D], parents: PackedInt32Array) -> Array[Transform3D]:
	var started: int = Time.get_ticks_usec() if _profiling_enabled else 0
	var result: Array[Transform3D]
	if _ensure_native_kernel():
		_stats.native_forward_calls += 1
		result = _native_kernel.call("forward_pose", poses, parents)
	else:
		_stats.reference_forward_calls += 1
		_stats.unavailable_fallback_calls += 1 if _native_enabled else 0
		result = forward_reference(poses, parents)
	if _profiling_enabled:
		_stats.forward_us += Time.get_ticks_usec() - started
	return result

## Identical parent-before-child multiply order, including non-topological
## bone indices, multiple roots and actual animated (not rest) local offsets.
## Empty output rejects malformed topology; valid rigs keep existing behavior.
static func forward_reference(poses: Array[Transform3D], parents: PackedInt32Array) -> Array[Transform3D]:
	var globals: Array[Transform3D] = []
	if poses.size() != parents.size():
		return globals
	globals.resize(poses.size())
	var state := PackedByteArray()
	state.resize(poses.size())
	for index: int in poses.size():
		if not _forward_bone(index, poses, parents, globals, state):
			return []
	return globals

static func _forward_bone(index: int, poses: Array[Transform3D], parents: PackedInt32Array,
		globals: Array[Transform3D], state: PackedByteArray) -> bool:
	if state[index] == 2:
		return true
	if state[index] == 1:
		return false
	state[index] = 1
	var parent: int = parents[index]
	if parent >= 0:
		if parent >= poses.size() or not _forward_bone(parent, poses, parents, globals, state):
			return false
		globals[index] = globals[parent] * poses[index]
	else:
		globals[index] = poses[index]
	state[index] = 2
	return true

static func _qp_dimensions_valid(h: Array, g: PackedFloat64Array, equalities: Array,
		inequalities: Array, limits: PackedFloat64Array, initial: PackedFloat64Array) -> bool:
	if h.size() != initial.size() or g.size() != initial.size() or limits.size() != inequalities.size():
		return false
	for matrix: Array in [h, equalities, inequalities]:
		for row: Variant in matrix:
			if not row is PackedFloat64Array or row.size() != initial.size():
				return false
	return true

## Reference retained for parity and unavailable-extension fallback. Thresholds,
## source-order ties, free-variable zeros and diagnostic payloads match native.
static func qp_reference(h: Array, g: PackedFloat64Array, equalities: Array, inequalities: Array, limits: PackedFloat64Array, initial: PackedFloat64Array) -> Dictionary:
	if not _qp_dimensions_valid(h, g, equalities, inequalities, limits, initial):
		return {"valid": false, "x": initial.duplicate(), "reason": "invalid_dimensions"}
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

