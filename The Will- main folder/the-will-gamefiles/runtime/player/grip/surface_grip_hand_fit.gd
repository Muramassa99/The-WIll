extends RefCounted

## One bounded fit for all digit hinges and the transverse weapon seat. Skin
## witnesses remain mobile; authored orientation, station and joint limits hold.
const DIGITS := [&"middle", &"index", &"ring", &"pinky", &"thumb"]
const VARIABLES := 17
const ITERATIONS := 20
const DERIVATIVE_DEGREES := 0.11459155902616 # 0.002 radians.
const MAX_ANGLE_STEP_DEGREES := 12.0
const MAX_SEAT_STEP_MM := 8.0
const CAP_WEIGHT := 10000.0
var _solver: RefCounted
var _reference := Transform3D.IDENTITY
var _move_seat := true
var _block: Array = []
var _target_count := 0
var _palm_begin := 0
var _palm_end := 0
var _groups: Array = []
var _group_for_target: Array[int] = []
var _lower: Array[float] = []
var _upper: Array[float] = []
var _opened: Array[float] = []
var _evaluations := 0
var _derivative_poses := 0
var _best: Dictionary = {}
var _constraint_passes := 0
var _active_constraints := 0


func fit(solver: RefCounted, reference: Transform3D, seeds: Array, move_seat: bool) -> Dictionary:
	var started := Time.get_ticks_usec()
	_solver = solver; _reference = reference; _move_seat = move_seat
	_prepare()
	var starts: Array = []
	var seed_choices: Array = []
	for index: int in seeds.size():
		if solver._cancelled(): break
		var angles: Dictionary = seeds[index].angles.duplicate(true)
		var open_thumb := _evaluate(_values(angles,seeds[index].weapon))
		_seed_thumb(angles, index)
		var preseeded := _evaluate(_values(angles,seeds[index].weapon))
		# A Thumb preshape must not discard an otherwise useful seated hand.
		# Keep one candidate per seat; this does not add optimizer basins.
		var use_preshape := _better(preseeded,open_thumb)
		var assessed: Dictionary = preseeded if use_preshape else open_thumb
		assessed["seed_index"] = index
		seed_choices.append({"index":index,"selected":&"thumb_preshape" if use_preshape else &"open_thumb",
			"open_thumb":{"safe":open_thumb.safe,"cost":open_thumb.cost,"max_excess_m":open_thumb.max_excess_m,
				"bone_crossings":open_thumb.bone_crossings,"palm_gap_m":open_thumb.palm_gap_m},
			"thumb_preshape":{"safe":preseeded.safe,"cost":preseeded.cost,"max_excess_m":preseeded.max_excess_m,
				"bone_crossings":preseeded.bone_crossings,"palm_gap_m":preseeded.palm_gap_m}})
		starts.append(assessed)
		_remember(assessed)
	starts.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return _better(a,b))
	var traces: Array = []
	for basin: int in mini(2, starts.size()):
		var selected: Dictionary = starts[basin]
		var damping := 0.0001
		var trace: Array = []
		for iteration: int in ITERATIONS:
			if solver._cancelled(): break
			var model := _model(selected)
			var accepted := false
			for retry: int in 2:
				var move := _bounded_step(_solve(model, damping, selected.values), selected.values)
				if _step_size(move) < 0.00001: break
				for fraction: float in [1.0,0.5,0.25,0.125]:
					if solver._cancelled(): break
					var values: Array = selected.values.duplicate()
					for variable: int in VARIABLES: values[variable] += move[variable] * fraction
					var next := _evaluate(values)
					_remember(next)
					# Once a safe pose exists along this path, a lower style/contact
					# score cannot purchase a material or bone intersection.
					if selected.safe and not next.safe: continue
					if next.cost < selected.cost - 0.000001 or (next.safe and not selected.safe):
						trace.append({"iteration":iteration,"cost_before":selected.cost,"cost_after":next.cost,
							"safe":next.safe,"max_excess_m":next.max_excess_m,"palm_gap_m":next.palm_gap_m,
							"active_rows":model.rows,"step_fraction":fraction,"damping":damping,
							"constraint_passes":_constraint_passes,"active_constraints":_active_constraints})
						selected = next; accepted = true
						damping = maxf(0.00000001,damping*0.3)
						break
				if accepted: break
				damping = minf(1.0,damping*10.0)
			if not accepted: break
		traces.append({"basin":basin,"seed_index":starts[basin].seed_index,"initial_cost":starts[basin].cost,"final_cost":selected.cost,
			"accepted_steps":trace.size(),"trace":trace})
	if _best.is_empty(): return {"valid":false,"reason":"whole_hand_candidates_unavailable"}
	_solver._weapon = _best.weapon
	var final: Dictionary = _solver._assess(_best.angles)
	return {"valid":true,"angles":_best.angles,"assessment":final,
		"metrics":{"method":&"coupled_whole_hand_surface_fit","variables":VARIABLES,
			"initial_candidates":starts.size(),"seed_choices":seed_choices,"basins_fitted":traces.size(),"iterations_per_basin":ITERATIONS,
			"evaluations":_evaluations,"derivative_poses":_derivative_poses,"point_count":_block.size(),
			"target_count":_target_count,"palm_count":_palm_end-_palm_begin,"traces":traces,
			"attraction_witnesses":_attraction_witnesses(),
			"safe":final.safe,"max_excess_m":final.max_excess_m,"palm_gap_m":final.palm_gap_m,
			"total_ms":float(Time.get_ticks_usec()-started)/1000.0}}


func _attraction_witnesses() -> Array:
	var out: Array=[]
	for group: int in _best.chosen.size():
		var selected: Dictionary=_best.chosen[group]
		if selected.is_empty(): continue
		var index: int=selected.index
		var sample: Dictionary=_block[index].sample
		var definition: Dictionary=_groups[group]
		var bary: Vector3=sample.barycentric
		var point: Vector3=_best.points[index]+_best.weapon.origin
		var closest: Vector3=_best.physical.closest_points[index]+_best.weapon.origin
		out.append({"digit":definition.digit,"section":"%s:S%d" % [definition.digit,int(definition.section)+1],
			"section_index":int(definition.section)+1,"percent":sample.get("percent",-1.0),
			"bell":sample.get("bell",1.0),"score":selected.score,"section_pull_weight":definition.weight,
			"physical_gap_m":_best.physical.signed_distances[index],"cap_m":_block[index].cap,
			"wrapper_target_gap_m":float(selected.target_gap)*0.001,"facing":selected.facing,
			"triangle_id":sample.get("triangle_id",-1),"source_id":sample.get("source_id",""),
			"vertex_ids":Array(sample.vertex_ids),"barycentric":[bary.x,bary.y,bary.z],
			"point_world":[point.x,point.y,point.z],"physical_closest_world":[closest.x,closest.y,closest.z],
			"vectors_origin_id":_solver.ROOT,"selection":&"optimizer_weighted_contact_witness"})
	return out


func _prepare() -> void:
	_block=[]; _groups=[]; _group_for_target=[]; _lower=[]; _upper=[]; _opened=[]
	_evaluations=0; _derivative_poses=0; _best={}
	for digit: StringName in DIGITS:
		var snapshot: Dictionary = _solver._prepared.adapter.digit_inputs[digit].snapshot
		for joint: int in 3:
			_lower.append(rad_to_deg(float(snapshot.min_angles_rad[joint])))
			_upper.append(rad_to_deg(float(snapshot.max_angles_rad[joint])))
			_opened.append(rad_to_deg(float(_solver._prepared.open_angles[digit][joint])))
		var indices := {}
		for section: int in 3:
			if digit == &"thumb" and section == 0: continue
			indices[section] = _groups.size()
			_groups.append({"digit":digit,"section":section,"weight":_solver.SECTION_PULL_WEIGHTS[section]})
		for carrier: Dictionary in _solver._blocks[digit]:
			var section := int(carrier.sample.get("target_section",-1))
			if section < 0 or not indices.has(section): continue
			_block.append(carrier)
			_group_for_target.append(indices[section])
	_target_count = _block.size()
	_palm_begin = _block.size(); _block.append_array(_solver._palm); _palm_end = _block.size()
	# Prepared full-skin guards already deduplicate shared vertices by cap.
	# They are checked once here, not independently by each affected digit.
	_block.append_array(_solver._safety)
	_lower.append(-INF); _lower.append(-INF); _upper.append(INF); _upper.append(INF)


func _seed_thumb(angles: Dictionary, index: int) -> void:
	var snapshot: Dictionary = _solver._prepared.adapter.digit_inputs[&"thumb"].snapshot
	# Legal preshapes, not additional joint constraints or a second thumb solve.
	var shapes := [Vector3(0.25,0.25,0.40),Vector3(0.45,0.40,0.55),Vector3(0.65,0.50,0.70)]
	var shape: Vector3 = shapes[(index/2) % shapes.size()]
	for joint: int in 3:
		var opened := float(_solver._prepared.open_angles[&"thumb"][joint])
		var positive := float(snapshot.max_angles_rad[joint])-opened
		var negative := opened-float(snapshot.min_angles_rad[joint])
		var travel := positive if positive >= negative else -negative
		angles[&"thumb"][joint] = clampf(opened+travel*shape[joint],snapshot.min_angles_rad[joint],snapshot.max_angles_rad[joint])


func _values(angles: Dictionary, weapon: Transform3D) -> Array:
	var values: Array = []
	for digit: StringName in DIGITS:
		for joint: int in 3: values.append(rad_to_deg(float(angles[digit][joint])))
	var shift := weapon.origin-_reference.origin
	values.append(shift.dot(_solver._tangent)*1000.0 if _move_seat else 0.0)
	values.append(shift.dot(_solver._outward)*1000.0 if _move_seat else 0.0)
	return values


func _evaluate(values: Array) -> Dictionary:
	_evaluations += 1
	_solver._metrics.candidate_steps += 1
	var bounded: Array = values.duplicate()
	var angles := {}
	for digit_index: int in DIGITS.size():
		var snapshot: Dictionary = _solver._prepared.adapter.digit_inputs[DIGITS[digit_index]].snapshot
		var selected: Array[float] = []
		for joint: int in 3:
			var variable := digit_index*3+joint
			bounded[variable] = clampf(float(values[variable]),_lower[variable],_upper[variable])
			var radians := clampf(deg_to_rad(float(bounded[variable])),float(snapshot.min_angles_rad[joint]),float(snapshot.max_angles_rad[joint]))
			selected.append(radians)
			bounded[variable] = rad_to_deg(radians)
		angles[DIGITS[digit_index]] = selected
	var weapon := _reference
	if _move_seat:
		weapon.origin += (_solver._tangent*float(bounded[15])+_solver._outward*float(bounded[16]))*0.001
	else: bounded[15]=0.0; bounded[16]=0.0
	_solver._weapon = weapon
	var states: Dictionary = _solver._states(angles)
	var frames: Dictionary = _solver._frames(states)
	var points: PackedVector3Array = _solver._points(_block,frames)
	var physical: Dictionary = _solver._query(&"physical",points)
	var normals: Dictionary = _solver._target_normals(_block,frames)
	var targets := points.slice(0,_target_count)
	var wrapper: Dictionary = _solver._query(&"digit",targets)
	var wrapper_s1: Dictionary = _solver._query(&"non_thumb_s1",targets)
	var chosen: Array = []
	for group: int in _groups.size(): chosen.append({})
	var cost := 0.0
	var max_excess := 0.0
	var nearest_palm := -1
	for index: int in _block.size():
		var carrier: Dictionary = _block[index]
		var gap := float(physical.signed_distances[index])
		var excess := -gap-float(carrier.cap)
		max_excess=maxf(max_excess,excess)
		cost += CAP_WEIGHT*pow(maxf(excess+_solver.CONTACT_BAND_M,0.0)*1000.0,2.0)
		if index >= _palm_begin and index < _palm_end:
			cost += 100.0*pow(maxf(-gap-_solver.PALM_CAP_M,0.0)*1000.0,2.0)
			if nearest_palm < 0 or gap < float(physical.signed_distances[nearest_palm]): nearest_palm=index
		if index >= _target_count: continue
		var group: int = _group_for_target[index]
		var definition: Dictionary = _groups[group]
		var kind: StringName = &"non_thumb_s1" if definition.section == 0 and definition.digit != &"thumb" else &"digit"
		var target_normal: Vector3 = wrapper_s1.normals[index] if kind == &"non_thumb_s1" else wrapper.normals[index]
		var target_gap := float(wrapper_s1.signed_distances[index] if kind == &"non_thumb_s1" else wrapper.signed_distances[index])
		target_gap=(target_gap+_solver._target_depth_delta(kind,target_normal))*1000.0
		var error: float = (gap+float(carrier.cap)-_solver.CONTACT_BAND_M)*1000.0
		var separation: float = maxf(gap-_solver.CONTACT_BAND_M,0.0)*1000.0
		var facing: float = (normals[index] as Vector3).dot(physical.normals[index])
		var score: float = 16.0*separation*separation+0.15*error*error+0.15*target_gap*target_gap+_solver.LOCATION_PREFERENCE_WEIGHT*(1.0-float(carrier.sample.get("bell",1.0)))
		if facing > 0.0: score += 100.0+1000.0*facing*facing
		if chosen[group].is_empty() or score < float(chosen[group].score):
			chosen[group]={"index":index,"score":score,"depth":error,"separation":separation,
				"target_gap":target_gap,"target_normal":target_normal,"facing":facing}
	for group: int in chosen.size():
		cost += (INF if chosen[group].is_empty() else float(chosen[group].score))*float(_groups[group].weight)
	var palm_gap := INF if nearest_palm < 0 else float(physical.signed_distances[nearest_palm])
	cost += 8.0*pow((palm_gap+_solver.PALM_CAP_M-_solver.CONTACT_BAND_M)*1000.0,2.0)
	cost += 64.0*pow(maxf(palm_gap-_solver.CONTACT_BAND_M,0.0)*1000.0,2.0)
	for digit_index: int in 4:
		var middle := absf(float(bounded[digit_index*3+1])-_opened[digit_index*3+1])
		var distal := absf(float(bounded[digit_index*3+2])-_opened[digit_index*3+2])
		cost += _solver.DISTRIBUTED_BEND_WEIGHT*pow(distal-_solver.DISTAL_TO_MIDDLE_BEND_RATIO*middle,2.0)
	var crossings := 0
	for digit: StringName in DIGITS: crossings += _solver._bone_crossings(states,digit)
	cost += crossings*100000.0
	return {"values":bounded,"angles":angles,"weapon":weapon,"states":states,"frames":frames,
		"points":points,"physical":physical,"normals":normals,"chosen":chosen,"nearest_palm":nearest_palm,
		"cost":cost,"safe":max_excess <= _solver.NUMERIC_GUARD_M and crossings == 0,
		"max_excess_m":max_excess,"bone_crossings":crossings,"palm_gap_m":palm_gap,
		"palm_engaged":palm_gap <= _solver.CONTACT_BAND_M and palm_gap >= -_solver.PALM_CAP_M-_solver.NUMERIC_GUARD_M}


func _model(pose: Dictionary) -> Dictionary:
	_solver._weapon=pose.weapon
	var shifted: Array=[]
	var shifted_normals: Array=[]
	var steps: Array[float]=[]
	for variable: int in 15:
		var digit_index: int=variable/3
		var joint: int=variable%3
		var digit: StringName=DIGITS[digit_index]
		var snapshot: Dictionary=_solver._prepared.adapter.digit_inputs[digit].snapshot
		var delta := DERIVATIVE_DEGREES if _upper[variable]-float(pose.values[variable]) >= DERIVATIVE_DEGREES else -DERIVATIVE_DEGREES
		var moved := clampf(float(pose.values[variable])+delta,_lower[variable],_upper[variable])
		var values: Array[float]=[]
		for angle: float in pose.angles[digit]: values.append(angle)
		values[joint]=clampf(deg_to_rad(moved),float(snapshot.min_angles_rad[joint]),float(snapshot.max_angles_rad[joint]))
		steps.append(rad_to_deg(values[joint])-float(pose.values[variable]))
		var state: Dictionary=_solver._spatial._forward_kinematics(snapshot,values)
		var frames: Dictionary=pose.frames.duplicate()
		for bone: int in 3: frames[snapshot.bone_names[bone]]=state.joint_transforms_world[bone]
		shifted.append(_solver._points(_block,frames))
		shifted_normals.append(_solver._target_normals(_block,frames))
		_derivative_poses += 1
	var h: Array=[]; h.resize(VARIABLES*VARIABLES); h.fill(0.0)
	var b: Array=[]; b.resize(VARIABLES); b.fill(0.0)
	var model: Dictionary={"h":h,"b":b,"rows":0,"constraints":[]}
	for index: int in _block.size():
		var physical_gap: float=(float(pose.physical.signed_distances[index])+float(_block[index].cap))*1000.0
		var residual: float=physical_gap-_solver.CONTACT_BAND_M*1000.0
		var jac:=_jacobian(pose.points,shifted,steps,index,pose.physical.normals[index])
		if residual < 0.0:
			_row(model,jac,residual,CAP_WEIGHT)
		# A guard need not be violated already to limit this step. Keep every
		# guard whose linearized clearance can close within the trust bounds.
		var travel:=0.0
		for variable: int in 15: travel += absf(float(jac[variable]))*MAX_ANGLE_STEP_DEGREES
		travel += (absf(float(jac[15]))+absf(float(jac[16])))*MAX_SEAT_STEP_MM
		var clearance: float=physical_gap-_solver.NUMERIC_GUARD_M*1000.0
		if clearance <= travel and travel > 0.000000001:
			model.constraints.append({"jac":jac,"gap":clearance})
	for group: int in pose.chosen.size():
		var selected: Dictionary=pose.chosen[group]
		if selected.is_empty(): continue
		var index: int=selected.index
		var weight: float=_groups[group].weight
		var jac:=_jacobian(pose.points,shifted,steps,index,pose.physical.normals[index])
		if selected.separation > 0.0: _row(model,jac,selected.separation,16.0*weight)
		_row(model,jac,selected.depth,0.15*weight)
		_row(model,_jacobian(pose.points,shifted,steps,index,selected.target_normal),selected.target_gap,0.15*weight)
		if selected.facing > 0.0:
			var facing_jac: Array=[]; facing_jac.resize(VARIABLES); facing_jac.fill(0.0)
			for variable: int in 15:
				if absf(steps[variable]) < 0.00000001: continue
				var normal_delta: Vector3=shifted_normals[variable][index]-pose.normals[index]
				facing_jac[variable]=normal_delta.dot(pose.physical.normals[index])/steps[variable]
			_row(model,facing_jac,selected.facing,1000.0*weight)
	for index: int in range(_palm_begin,_palm_end):
		var gap: float=pose.physical.signed_distances[index]
		if gap < -_solver.PALM_CAP_M:
			_row(model,_jacobian(pose.points,shifted,steps,index,pose.physical.normals[index]),(gap+_solver.PALM_CAP_M)*1000.0,100.0)
	if pose.nearest_palm >= 0:
		var index: int=pose.nearest_palm
		var jac:=_jacobian(pose.points,shifted,steps,index,pose.physical.normals[index])
		_row(model,jac,(pose.palm_gap_m+_solver.PALM_CAP_M-_solver.CONTACT_BAND_M)*1000.0,8.0)
		if pose.palm_gap_m > _solver.CONTACT_BAND_M:
			_row(model,jac,(pose.palm_gap_m-_solver.CONTACT_BAND_M)*1000.0,64.0)
	for digit_index: int in 4:
		var middle_index:=digit_index*3+1
		var distal_index:=digit_index*3+2
		var middle:=float(pose.values[middle_index])-_opened[middle_index]
		var distal:=float(pose.values[distal_index])-_opened[distal_index]
		var jac: Array=[]; jac.resize(VARIABLES); jac.fill(0.0)
		jac[middle_index]=-_solver.DISTAL_TO_MIDDLE_BEND_RATIO*_bend_slope(middle_index,middle)
		jac[distal_index]=_bend_slope(distal_index,distal)
		_row(model,jac,absf(distal)-_solver.DISTAL_TO_MIDDLE_BEND_RATIO*absf(middle),_solver.DISTRIBUTED_BEND_WEIGHT)
	return model


func _jacobian(points: PackedVector3Array, shifted: Array, steps: Array[float], index: int, normal: Vector3) -> Array:
	var jac: Array=[]; jac.resize(VARIABLES); jac.fill(0.0)
	for variable: int in 15:
		if absf(steps[variable]) > 0.00000001:
			jac[variable]=normal.dot((shifted[variable] as PackedVector3Array)[index]-points[index])*1000.0/steps[variable]
	if _move_seat:
		jac[15]=-normal.dot(_solver._tangent)
		jac[16]=-normal.dot(_solver._outward)
	return jac


func _row(model: Dictionary, jac: Array, residual: float, weight: float) -> void:
	var active: Array[int]=[]
	for index: int in VARIABLES:
		if absf(float(jac[index])) > 0.000000001: active.append(index)
	for row: int in active:
		model.b[row] -= weight*float(jac[row])*residual
		for column: int in active: model.h[row*VARIABLES+column] += weight*float(jac[row])*float(jac[column])
	model.rows += 1


func _solve(model: Dictionary, damping: float, values: Array) -> Array:
	var factor:=_factor(model.h,damping)
	var unconstrained:=_backsolve(factor,model.b)
	var constraints: Array=model.get("constraints",[]).duplicate()
	for variable: int in VARIABLES:
		if variable >= 15 and _move_seat: continue
		var lower:=_lower[variable] if variable < 15 else 0.0
		var upper:=_upper[variable] if variable < 15 else 0.0
		var low_jac: Array=[]; low_jac.resize(VARIABLES); low_jac.fill(0.0); low_jac[variable]=1.0
		var high_jac: Array=[]; high_jac.resize(VARIABLES); high_jac.fill(0.0); high_jac[variable]=-1.0
		constraints.append({"jac":low_jac,"gap":float(values[variable])-lower})
		constraints.append({"jac":high_jac,"gap":upper-float(values[variable])})
	var active: Array[int]=[]
	var inverse_rows: Dictionary={}
	var result: Array=unconstrained.duplicate()
	_constraint_passes=0; _active_constraints=0
	# Working-set QP: H*d=b+A^T*lambda, A*d+gap=0, lambda>=0.
	# Schur rows are regularized only at roundoff scale for duplicate skin guards.
	for pass_index: int in 40:
		_constraint_passes=pass_index+1
		if not active.is_empty():
			var matrix: Array=[]
			for row: int in active:
				if not inverse_rows.has(row): inverse_rows[row]=_backsolve(factor,constraints[row].jac)
			for row: int in active:
				var entries: Array=[]
				for column: int in active:
					var coefficient:=_dot(constraints[row].jac,inverse_rows[column])
					if row == column: coefficient += maxf(0.0000000001,absf(coefficient)*0.0000000001)
					entries.append(coefficient)
				entries.append(-float(constraints[row].gap)-_dot(constraints[row].jac,unconstrained))
				matrix.append(entries)
			var multipliers:=_eliminate(matrix)
			var release:=-1
			var most_negative:=-0.0000001
			for entry: int in multipliers.size():
				if float(multipliers[entry]) < most_negative:
					most_negative=float(multipliers[entry]); release=entry
			if release >= 0:
				active.remove_at(release)
				result=unconstrained.duplicate()
				continue
			result=unconstrained.duplicate()
			for entry: int in active.size():
				var direction: Array=inverse_rows[active[entry]]
				for variable: int in VARIABLES: result[variable] += float(direction[variable])*float(multipliers[entry])
		var worst:=-1
		var worst_gap:=-0.000001
		for index: int in constraints.size():
			if index in active: continue
			var predicted:=float(constraints[index].gap)+_dot(constraints[index].jac,result)
			if predicted < worst_gap: worst_gap=predicted; worst=index
		if worst < 0: break
		active.append(worst)
	_active_constraints=active.size()
	return result


func _factor(h: Array,damping: float) -> Array:
	var lower: Array=[]; lower.resize(VARIABLES*VARIABLES); lower.fill(0.0)
	for row: int in VARIABLES:
		for column: int in range(row+1):
			var value:=float(h[row*VARIABLES+column])
			if row == column: value += maxf(0.0001,maxf(1.0,value)*damping)
			for inner: int in column: value -= float(lower[row*VARIABLES+inner])*float(lower[column*VARIABLES+inner])
			lower[row*VARIABLES+column]=sqrt(maxf(value,0.000000000001)) if row == column else value/float(lower[column*VARIABLES+column])
	return lower


func _backsolve(lower: Array,rhs: Array) -> Array:
	var out: Array=[]; out.resize(VARIABLES); out.fill(0.0)
	for row: int in VARIABLES:
		var value:=float(rhs[row])
		for column: int in row: value -= float(lower[row*VARIABLES+column])*float(out[column])
		out[row]=value/float(lower[row*VARIABLES+row])
	for row: int in range(VARIABLES-1,-1,-1):
		var value:=float(out[row])
		for column: int in range(row+1,VARIABLES): value -= float(lower[column*VARIABLES+row])*float(out[column])
		out[row]=value/float(lower[row*VARIABLES+row])
	return out


func _dot(a: Array,b: Array) -> float:
	var result:=0.0
	for index: int in VARIABLES: result += float(a[index])*float(b[index])
	return result


func _eliminate(matrix: Array) -> Array:
	var size:=matrix.size()
	var out: Array=[]; out.resize(size); out.fill(0.0)
	for column: int in size:
		var pivot:=column
		for row: int in range(column+1,size):
			if absf(float(matrix[row][column])) > absf(float(matrix[pivot][column])): pivot=row
		if absf(float(matrix[pivot][column])) < 0.000000000001: return out
		if pivot != column:
			var swap: Array=matrix[column]; matrix[column]=matrix[pivot]; matrix[pivot]=swap
		var divisor:=float(matrix[column][column])
		for entry: int in range(column,size+1): matrix[column][entry] /= divisor
		for row: int in range(column+1,size):
			var factor:=float(matrix[row][column])
			for entry: int in range(column,size+1): matrix[row][entry] -= factor*float(matrix[column][entry])
	for row: int in range(size-1,-1,-1):
		var value:=float(matrix[row][size])
		for column: int in range(row+1,size): value -= float(matrix[row][column])*float(out[column])
		out[row]=value
	return out


func _bounded_step(move: Array, values: Array) -> Array:
	var scale:=1.0
	for variable: int in 15:
		var change:=float(move[variable])
		# Schur regularization can leave a tiny outward component on
		# an active bound. Remove that roundoff, not the useful coupled motion.
		if absf(change) < 0.00001 and ((float(values[variable]) <= _lower[variable]+0.000001 and change < 0.0) or (float(values[variable]) >= _upper[variable]-0.000001 and change > 0.0)):
			move[variable]=0.0
			continue
		if absf(change) > MAX_ANGLE_STEP_DEGREES: scale=minf(scale,MAX_ANGLE_STEP_DEGREES/absf(change))
		if change > 0.0: scale=minf(scale,maxf(0.0,(_upper[variable]-float(values[variable]))/change))
		elif change < 0.0: scale=minf(scale,maxf(0.0,(_lower[variable]-float(values[variable]))/change))
	var distance:=Vector2(float(move[15]),float(move[16])).length()
	if distance > MAX_SEAT_STEP_MM: scale=minf(scale,MAX_SEAT_STEP_MM/distance)
	for variable: int in VARIABLES: move[variable] *= scale
	return move


func _step_size(move: Array) -> float:
	var maximum:=0.0
	for value: float in move: maximum=maxf(maximum,absf(value))
	return maximum


func _bend_slope(variable: int, delta: float) -> float:
	if absf(delta) > 0.00000001: return signf(delta)
	return 1.0 if _upper[variable]-_opened[variable] >= _opened[variable]-_lower[variable] else -1.0


func _better(candidate: Dictionary,current: Dictionary) -> bool:
	if current.is_empty(): return true
	if candidate.safe != current.safe: return candidate.safe
	if candidate.safe and candidate.palm_engaged != current.palm_engaged: return candidate.palm_engaged
	if not candidate.safe and absf(candidate.max_excess_m-current.max_excess_m) > _solver.NUMERIC_GUARD_M:
		return candidate.max_excess_m < current.max_excess_m
	return candidate.cost < current.cost


func _remember(pose: Dictionary) -> void:
	if _better(pose,_best): _best=pose
