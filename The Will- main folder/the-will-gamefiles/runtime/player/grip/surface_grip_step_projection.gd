extends RefCounted

## Small feasible active-set projection for the dimensionless joint/translation
## request. Minimize ||step-request||^2 subject to row.dot(step) <= bound.
## Zero is the supplied feasible pose; this helper never relaxes a material cap.
## Active constraints can leave the working set when their multiplier is negative.
## Permanently binding every encountered plane can incorrectly eliminate motion.
const MAX_ACTIVE_SET_ITERATIONS := 96
const FEASIBILITY_TOLERANCE := 1.0e-9
const DIRECTION_TOLERANCE_SQUARED := 1.0e-20
const MULTIPLIER_TOLERANCE := 1.0e-10
const GRAM_PIVOT_TOLERANCE := 1.0e-12


static func limit(request: PackedFloat64Array, constraints: Array) -> PackedFloat64Array:
	var dimension := request.size()
	var result := _zeros(dimension)
	if dimension == 0: return result
	for value: float in request:
		if not is_finite(value): return result
	var rows: Array[PackedFloat64Array] = []
	var bounds := PackedFloat64Array()
	for constraint: Dictionary in constraints:
		var source: Variant = constraint.get("row")
		if not source is PackedFloat64Array or source.size() != dimension: return result
		var row: PackedFloat64Array = source
		for value: float in row:
			if not is_finite(value): return result
		var bound := float(constraint.get("bound", 0.0))
		if not is_finite(bound): return result
		var length := sqrt(_dot(row, row))
		if length <= 1.0e-15: continue
		rows.append(_scaled(row, 1.0 / length))
		bounds.append(maxf(bound, 0.0) / length)
	if rows.is_empty(): return request.duplicate()
	var active: Array[int] = []
	var best := result.duplicate()
	var best_error := _distance_squared(result, request)
	for _iteration: int in MAX_ACTIVE_SET_ITERATIONS:
		var residual := request.duplicate()
		for coordinate: int in dimension: residual[coordinate] -= result[coordinate]
		var multipliers := _multipliers(rows, active, residual)
		# A dependent working set is a numeric failure, not authority to step
		# through a constraint. Keep the best previously feasible result.
		if not multipliers.get("valid", false): return best
		var values: PackedFloat64Array = multipliers["multipliers"]
		var direction := residual.duplicate()
		for working: int in active.size():
			var row: PackedFloat64Array = rows[active[working]]
			for coordinate: int in dimension: direction[coordinate] -= values[working] * row[coordinate]
		if _dot(direction, direction) <= DIRECTION_TOLERANCE_SQUARED:
			var release := -1
			var smallest := -MULTIPLIER_TOLERANCE
			for working: int in values.size():
				if values[working] < smallest:
					smallest = values[working]
					release = working
			if release < 0: return best
			active.remove_at(release)
			continue
		var fraction := 1.0
		var blocking := -1
		for index: int in rows.size():
			if active.has(index): continue
			var travel := _dot(rows[index], direction)
			if travel <= 1.0e-12: continue
			var available := maxf(bounds[index] - _dot(rows[index], result), 0.0) / travel
			if available < fraction:
				fraction = available
				blocking = index
		var candidate := result.duplicate()
		for coordinate: int in dimension: candidate[coordinate] += fraction * direction[coordinate]
		if not _feasible(candidate, rows, bounds): return best
		result = candidate
		var error := _distance_squared(result, request)
		if error < best_error:
			best = result.duplicate()
			best_error = error
		if blocking >= 0:
			active.append(blocking)
		# On a full step, the next iteration tests multipliers before stopping:
		# a face encountered earlier may now need releasing to reach the optimum.
	return best


static func _multipliers(rows: Array[PackedFloat64Array], active: Array[int], residual: PackedFloat64Array) -> Dictionary:
	var count := active.size()
	var rhs := _zeros(count)
	var gram: Array[PackedFloat64Array] = []
	for i: int in count:
		var row := _zeros(count)
		for j: int in count: row[j] = _dot(rows[active[i]], rows[active[j]])
		gram.append(row)
		rhs[i] = _dot(rows[active[i]], residual)
	# Partial pivoting on the normalized Gram system. The working set has at
	# most dimension independent rows, so no general matrix dependency is needed.
	for column: int in count:
		var pivot := column
		for i: int in range(column + 1, count):
			if absf(gram[i][column]) > absf(gram[pivot][column]): pivot = i
		if absf(gram[pivot][column]) <= GRAM_PIVOT_TOLERANCE:
			return {"valid": false}
		if pivot != column:
			var swapped: PackedFloat64Array = gram[column]
			gram[column] = gram[pivot]
			gram[pivot] = swapped
			var scalar := rhs[column]
			rhs[column] = rhs[pivot]
			rhs[pivot] = scalar
		for i: int in range(column + 1, count):
			var factor := gram[i][column] / gram[column][column]
			for j: int in range(column, count): gram[i][j] -= factor * gram[column][j]
			rhs[i] -= factor * rhs[column]
	var values := _zeros(count)
	for i: int in range(count - 1, -1, -1):
		var remainder := rhs[i]
		for j: int in range(i + 1, count): remainder -= gram[i][j] * values[j]
		values[i] = remainder / gram[i][i]
	return {"valid": true, "multipliers": values}


static func _feasible(value: PackedFloat64Array, rows: Array[PackedFloat64Array], bounds: PackedFloat64Array) -> bool:
	for index: int in rows.size():
		if _dot(rows[index], value) > bounds[index] + FEASIBILITY_TOLERANCE: return false
	return true


static func _dot(a: PackedFloat64Array, b: PackedFloat64Array) -> float:
	var value := 0.0
	for index: int in a.size(): value += a[index] * b[index]
	return value


static func _zeros(size: int) -> PackedFloat64Array:
	var values := PackedFloat64Array()
	values.resize(size)
	values.fill(0.0)
	return values


static func _scaled(input: PackedFloat64Array, scale: float) -> PackedFloat64Array:
	var value := input.duplicate()
	for index: int in value.size(): value[index] *= scale
	return value


static func _distance_squared(a: PackedFloat64Array, b: PackedFloat64Array) -> float:
	var error := 0.0
	for index: int in a.size(): error += (a[index] - b[index]) * (a[index] - b[index])
	return error
