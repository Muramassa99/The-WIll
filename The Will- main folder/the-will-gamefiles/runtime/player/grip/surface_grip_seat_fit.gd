extends RefCounted

## Six whole-hand preshape alternatives to the coarse Middle-only seats.
## Each pose is fixed while a bounded two-coordinate translation seats the
## weapon. The shared hand fitter then refines joints and translation together.
const DIGITS := [&"middle", &"index", &"ring", &"pinky"]
const PRESHAPES := [Vector3(35,50,30), Vector3(55,75,45), Vector3(70,80,55)]
const SECTION_WEIGHTS := [0.6, 0.8, 0.3]
const PALM_WEIGHT := 8.0
const CAP_WEIGHT := 10000.0
const CONTACT_GUARD_M := 0.00005
const PALM_CAP_M := 0.0035
const MAX_STEP_M := 0.008
const ITERATIONS := 10
var metrics: Dictionary = {}
var _solver: RefCounted
var _targets: Array = []
var _keys: Array[StringName] = []
var _weights: Array[float] = []
var _frames: Dictionary
var _normals: Dictionary
var _u := Vector3.ZERO
var _v := Vector3.ZERO


func make_candidates(solver: RefCounted, original_weapon: Transform3D, open_angles: Dictionary) -> Array:
	var started := Time.get_ticks_usec()
	_solver = solver
	_u = solver._tangent
	_v = solver._outward
	_targets = []; _keys = []; _weights = []
	metrics = {"trials":[], "max_iterations":ITERATIONS, "max_step_m":MAX_STEP_M,
		"candidate_count":0, "joint_angles_changed_during_seating":false}
	for digit: StringName in DIGITS:
		for carrier: Dictionary in solver._blocks[digit]:
			var section := int(carrier.sample.get("target_section", -1))
			if section < 0: continue
			_targets.append(carrier)
			_keys.append(StringName("%s:S%d" % [digit, section + 1]))
			_weights.append(SECTION_WEIGHTS[section])
	var previous_weapon: Transform3D = solver._weapon
	var open_states: Dictionary = solver._states(open_angles)
	var candidates: Array = []
	for shape: Vector3 in PRESHAPES:
		if solver._cancelled(): break
		var angles := _preshape_angles(open_angles, shape)
		var states: Dictionary = solver._states(angles)
		_frames = solver._frames(states)
		_normals = solver._target_normals(_targets, _frames)
		for offset: float in [0.0, 0.020]:
			if solver._cancelled(): break
			solver._weapon = original_weapon
			solver._place_palm(open_states, offset)
			var trace: Array = []
			var current := _system()
			for iteration: int in ITERATIONS:
				if solver._cancelled(): break
				var move := _solve_step(current)
				trace.append({"iteration":iteration, "merit":current.merit,
					"max_excess_m":current.max_excess_m, "active_caps":current.active_caps,
					"palm_gap_m":current.palm_gap_m, "step_m":move.length()})
				if move.length() < 0.000005: break
				var before: Transform3D = solver._weapon
				var accepted := false
				for fraction: float in [1.0, 0.5, 0.25]:
					var proposed := before
					proposed.origin = original_weapon.origin + solver._transverse(before.origin + move * fraction - original_weapon.origin)
					proposed.basis = original_weapon.basis
					solver._weapon = proposed
					var next := _system()
					if next.merit < current.merit - 0.000001:
						current = next; accepted = true; break
				if not accepted:
					solver._weapon = before
					break
			var assessment: Dictionary = solver._assess(angles)
			metrics.trials.append({"preshape_degrees":shape, "initial_tangent_offset_m":offset,
				"trace":trace, "whole_hand_cost":assessment.cost,
				"safe":assessment.safe, "max_excess_m":assessment.max_excess_m,
				"palm_gap_m":assessment.palm_gap_m, "weapon":solver._weapon})
			candidates.append({"weapon":assessment.weapon, "angles":angles.duplicate(true), "cost":assessment.cost,
				"source":&"whole_hand_preshape_translation", "whole_hand_cost":assessment.cost,
				"safe":assessment.safe, "preshape_degrees":shape, "initial_tangent_offset_m":offset})
	solver._weapon = previous_weapon
	metrics.candidate_count = candidates.size()
	metrics["total_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	return candidates


func _preshape_angles(open_angles: Dictionary, shape: Vector3) -> Dictionary:
	var angles := open_angles.duplicate(true)
	for digit: StringName in DIGITS:
		var snapshot: Dictionary = _solver._prepared.adapter.digit_inputs[digit].snapshot
		for joint: int in 3:
			var opened := float(open_angles[digit][joint])
			var sign := -1.0 if absf(float(snapshot.min_angles_rad[joint]) - opened) > absf(float(snapshot.max_angles_rad[joint]) - opened) else 1.0
			angles[digit][joint] = clampf(opened + sign * deg_to_rad(shape[joint]), snapshot.min_angles_rad[joint], snapshot.max_angles_rad[joint])
	return angles


func _system() -> Dictionary:
	var state := {"xx":0.0, "xy":0.0, "yy":0.0, "bx":0.0, "by":0.0,
		"merit":0.0, "max_excess_m":0.0, "active_caps":0, "palm_gap_m":INF}
	var target: Dictionary = _solver._query(&"physical", _solver._points(_targets, _frames))
	var chosen: Dictionary = {}
	for index: int in _targets.size():
		var carrier: Dictionary = _targets[index]
		var gap := float(target.signed_distances[index])
		var normal: Vector3 = target.normals[index]
		var facing: float = (_normals.get(index, Vector3.ZERO) as Vector3).dot(normal)
		if facing >= 0.0: continue
		var residual := gap + float(carrier.cap) - CONTACT_GUARD_M
		var bell := float(carrier.sample.get("bell", 1.0))
		var score := residual * residual * (1.0 + 0.5 * (1.0 - bell))
		var key: StringName = _keys[index]
		if not chosen.has(key) or score < float(chosen[key].score):
			chosen[key] = {"normal":normal, "residual":residual, "score":score, "weight":_weights[index]}
	for selected: Dictionary in chosen.values():
		_row(state, selected.normal, selected.residual, selected.weight)
		state.merit += selected.score * selected.weight * 1000000.0
	# Losing every correctly facing witness must not lower the objective simply
	# because no attraction row remains for that section.
	state.merit += float(12 - chosen.size()) * 10000.0
	var palm: Dictionary = _solver._query(&"physical", _solver._points(_solver._palm, _frames))
	var palm_index := -1
	for index: int in palm.signed_distances.size():
		if float(palm.signed_distances[index]) < float(state.palm_gap_m):
			state.palm_gap_m = palm.signed_distances[index]; palm_index = index
	if palm_index >= 0:
		var residual := float(state.palm_gap_m) + PALM_CAP_M - CONTACT_GUARD_M
		_row(state, palm.normals[palm_index], residual, PALM_WEIGHT)
		state.merit += residual * residual * PALM_WEIGHT * 1000000.0
	var physical: Dictionary = _solver._query(&"physical", _solver._points(_solver._safety, _frames))
	for index: int in _solver._safety.size():
		var gap := float(physical.signed_distances[index])
		var cap := float(_solver._safety[index].cap)
		var excess := maxf(-gap - cap, 0.0)
		state.max_excess_m = maxf(state.max_excess_m, excess)
		var residual := gap + cap - CONTACT_GUARD_M
		if residual >= 0.0: continue
		state.active_caps += 1
		_row(state, physical.normals[index], residual, CAP_WEIGHT)
		state.merit += residual * residual * CAP_WEIGHT * 1000000.0
	return state


func _row(state: Dictionary, normal: Vector3, residual: float, weight: float) -> void:
	# Translating the surface changes signed point distance by -normal dot move.
	var x := normal.dot(_u)
	var y := normal.dot(_v)
	state.xx += weight * x * x; state.xy += weight * x * y; state.yy += weight * y * y
	state.bx += weight * x * residual; state.by += weight * y * residual


func _solve_step(state: Dictionary) -> Vector3:
	var damping := maxf(0.0001, 0.002 * (float(state.xx) + float(state.yy)))
	var xx := float(state.xx) + damping
	var yy := float(state.yy) + damping
	var xy := float(state.xy)
	var determinant := xx * yy - xy * xy
	if determinant <= 0.000000000001: return Vector3.ZERO
	var x := (float(state.bx) * yy - float(state.by) * xy) / determinant
	var y := (float(state.by) * xx - float(state.bx) * xy) / determinant
	var move: Vector3 = _solver._transverse(_u * x + _v * y)
	return move.limit_length(MAX_STEP_M)
