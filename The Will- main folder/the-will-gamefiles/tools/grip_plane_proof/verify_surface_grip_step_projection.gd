extends SceneTree

## Independent bounded numerical proof; no character, scene, save or grip solve.
## The 2D oracle enumerates feasible edge feet and line intersections instead of
## reusing the production active-set algorithm.
const StepProjection = preload("res://runtime/player/grip/surface_grip_step_projection.gd")
const TOLERANCE := 1.0e-7
var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var started := Time.get_ticks_usec()
	var request := PackedFloat64Array([-0.6, -1.6])
	var constraints: Array = [_constraint([0.8, -1.0], 0.0), _constraint([-0.05, -1.0], 0.0)]
	var expected := PackedFloat64Array([-0.5187032418952618, 0.02593516209476321])
	_compare(request, constraints, expected, "release earlier boundary instead of false zero motion")
	constraints.reverse()
	_compare(request, constraints, expected, "reversed boundaries give identical correction")
	constraints.append(_constraint([-0.1, -2.0], 0.0))
	_compare(request, constraints, expected, "duplicate scaled boundaries do not pin additional directions")
	for dimension: int in [3, 14]:
		var embedded := _zeros(dimension)
		var wanted := _zeros(dimension)
		for index: int in dimension:
			embedded[index] = request[index] if index < 2 else sin(float(index)) * 1.4
			wanted[index] = expected[index] if index < 2 else clampf(embedded[index], -1.0, 1.0)
		var rows: Array = []
		for slope: float in [0.8, -0.05]:
			var row := _zeros(dimension)
			row[0] = slope; row[1] = -1.0
			rows.append({"row": row, "bound": 0.0})
		for index: int in dimension:
			var positive := _zeros(dimension)
			var negative := _zeros(dimension)
			positive[index] = 1.0; negative[index] = -1.0
			rows.append({"row": positive, "bound": 1.0})
			rows.append({"row": negative, "bound": 1.0})
		_compare(embedded, rows, wanted, "counterexample embedded in %d solver coordinates" % dimension)
		rows.reverse()
		_compare(embedded, rows, wanted, "%d coordinate bounds independent of row order" % dimension)
	for fixture: int in 48:
		var desired := PackedFloat64Array([cos(float(fixture) * 0.43) * 2.4, sin(float(fixture) * 0.71) * 2.1])
		var rows: Array = [_constraint([1.0, 0.0], 1.0), _constraint([-1.0, 0.0], 1.0),
			_constraint([0.0, 1.0], 1.0), _constraint([0.0, -1.0], 1.0)]
		for edge: int in 5:
			var angle := float(fixture) * 0.17 + float(edge) * 1.31
			rows.append(_constraint([cos(angle), sin(angle)], 0.0 if (fixture + edge) % 3 == 0 else 0.2 + float(edge) * 0.08))
		var oracle := _oracle(desired, rows)
		_compare(desired, rows, oracle, "2D independent oracle %d" % fixture)
		rows.reverse()
		_compare(desired, rows, oracle, "2D independent reversed oracle %d" % fixture)
	_compare(PackedFloat64Array([0.2, -0.3]), [], PackedFloat64Array([0.2, -0.3]), "unconstrained request is unchanged")
	_compare(PackedFloat64Array([2.0, 0.3]), [_constraint([1.0, 0.0], -0.1)], PackedFloat64Array([0.0, 0.3]), "negative roundoff allowance is clamped at current feasible pose")
	_check(StepProjection.limit(PackedFloat64Array([NAN, 1.0]), []) == PackedFloat64Array([0.0, 0.0]), "nonfinite request fails at feasible zero")
	_check(StepProjection.limit(PackedFloat64Array([1.0, 1.0]), [_constraint([1.0], 0.0)]) == PackedFloat64Array([0.0, 0.0]), "invalid constraint dimension fails at feasible zero")
	var report := {"schema": "surface_grip_step_projection_verification_v1", "ok": _failures.is_empty(),
		"checks": _checks, "failures": _failures, "elapsed_ms": float(Time.get_ticks_usec() - started) / 1000.0,
		"grip_solve_run": false, "production_save_written": false}
	var path := "C:/WORKSPACE/test_artifacts/verify_surface_grip_step_projection_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: push_error("Cannot write projection verifier output"); quit(1); return
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print("SURFACE_GRIP_PROJECTION_RESULT=" + path)
	print("SURFACE_GRIP_PROJECTION_SUMMARY=" + JSON.stringify(report))
	quit(0 if report.ok else 1)


func _constraint(values: Array, bound: float) -> Dictionary:
	return {"row": PackedFloat64Array(values), "bound": bound}


func _zeros(size: int) -> PackedFloat64Array:
	var result := PackedFloat64Array()
	result.resize(size); result.fill(0.0)
	return result


func _compare(request: PackedFloat64Array, constraints: Array, expected: PackedFloat64Array, label: String) -> void:
	var original := request.duplicate()
	var original_constraints := var_to_bytes(constraints)
	var actual := StepProjection.limit(request, constraints)
	var error := 0.0
	for index: int in expected.size(): error = maxf(error, absf(actual[index] - expected[index]))
	_check(error <= TOLERANCE, label + "; maximum coordinate error=" + str(error))
	_check(_feasible(actual, constraints), label + "; physical inequalities retained")
	_check(request == original and var_to_bytes(constraints) == original_constraints, label + "; inputs immutable")


func _oracle(request: PackedFloat64Array, constraints: Array) -> PackedFloat64Array:
	var candidates: Array[PackedFloat64Array] = [PackedFloat64Array([0.0, 0.0])]
	if _feasible(request, constraints): candidates.append(request)
	for i: int in constraints.size():
		var first: PackedFloat64Array = constraints[i].row
		var bound := maxf(float(constraints[i].bound), 0.0)
		var distance := (first[0] * request[0] + first[1] * request[1] - bound) / (first[0] * first[0] + first[1] * first[1])
		var foot := PackedFloat64Array([request[0] - first[0] * distance, request[1] - first[1] * distance])
		if _feasible(foot, constraints): candidates.append(foot)
		for j: int in range(i + 1, constraints.size()):
			var second: PackedFloat64Array = constraints[j].row
			var other := maxf(float(constraints[j].bound), 0.0)
			var determinant := first[0] * second[1] - first[1] * second[0]
			if absf(determinant) < 1.0e-12: continue
			var cross := PackedFloat64Array([(bound * second[1] - other * first[1]) / determinant,
				(first[0] * other - second[0] * bound) / determinant])
			if _feasible(cross, constraints): candidates.append(cross)
	var best := candidates[0]
	var best_error := INF
	for value: PackedFloat64Array in candidates:
		var error := pow(value[0] - request[0], 2.0) + pow(value[1] - request[1], 2.0)
		if error < best_error:
			best_error = error
			best = value
	return best


func _feasible(value: PackedFloat64Array, constraints: Array) -> bool:
	for constraint: Dictionary in constraints:
		var total := 0.0
		for index: int in value.size(): total += constraint.row[index] * value[index]
		if total > maxf(float(constraint.bound), 0.0) + TOLERANCE: return false
	return true


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition: _failures.append(label); push_error(label)
