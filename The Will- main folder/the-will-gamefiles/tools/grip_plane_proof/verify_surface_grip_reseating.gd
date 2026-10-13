extends SceneTree

## Current bounded final-pose contracts. Removed projected-reseat/contact-lock
## helper tests are retired. Analytical substitutes are not visual grip proof.
const Solver = preload("res://runtime/player/grip/surface_driven_grip_solver.gd")
const Anatomy = preload("res://runtime/player/grip/prepared_surface_grip_anatomy.gd")
const HandFit = preload("res://runtime/player/grip/surface_grip_hand_fit.gd")
const DIGITS: Array[StringName] = [&"middle",&"index",&"ring",&"pinky",&"thumb"]
var _checks := 0
var _failures: Array[String] = []

class Errors extends Logger:
	var entries: Array[Dictionary] = []
	func _log_error(function: String,file: String,line: int,code: String,rationale: String,_editor_notify: bool,error_type: int,_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING: entries.append({"function":function,"file":file,"line":line,"code":code,"rationale":rationale})
var _errors := Errors.new()

class CoupledPlaneProbe extends Solver:
	var poison_thumb_preshape := false
	func _query(kind: StringName,points: PackedVector3Array) -> Dictionary:
		var gaps:=PackedFloat64Array(); var normals:=PackedVector3Array(); var closest:=PackedVector3Array()
		var offset:=0.00495 if kind==&"non_thumb_s1" else (0.00345 if kind==&"digit" else 0.0)
		for point: Vector3 in points:
			gaps.append(point.x+offset); normals.append(Vector3.RIGHT); closest.append(Vector3(-offset,point.y,point.z))
		return {"valid":true,"signed_distances":gaps,"normals":normals,"closest_points":closest}
	func _target_normals(block: Array,_frames_input: Dictionary) -> Dictionary:
		var normals: Dictionary={}
		for index: int in block.size(): normals[index]=Vector3.LEFT
		return normals
	func _target_depth_delta(_kind: StringName,_normal: Vector3) -> float: return 0.0
	func _bone_crossings(states_input: Dictionary,id: StringName) -> int:
		if not poison_thumb_preshape or id!=&"thumb": return 0
		return 1 if (states_input[id].joint_transforms_world[0] as Transform3D).basis.get_rotation_quaternion().get_angle()>0.1 else 0

class PackedPoseProbe extends Anatomy:
	func pose_samples(_prepared_input: Dictionary,samples: Array,_overrides: Dictionary={}) -> Array:
		var result: Array=[]
		for sample: Dictionary in samples: result.append({"point_world":Vector3(0,0.05,0.01),"normal_world":Vector3.BACK})
		return result

class BoundaryPoseProbe extends Anatomy:
	func pose_samples(_prepared_input: Dictionary,samples: Array,_overrides: Dictionary={}) -> Array:
		var result: Array=[]
		for sample: Dictionary in samples:
			result.append({"point_world":Vector3(0.01,0.01,0.01),"normal_world":sample.test_normal})
		return result

class AssessmentProbe extends Solver:
	var physical_normal := Vector3.FORWARD
	var crossings := 0
	func _states(_angles_input: Dictionary) -> Dictionary: return {}
	func _frames(_states_input: Dictionary) -> Dictionary: return {}
	func _digit_cost(_id: StringName,_angles_input: Dictionary) -> float: return 0.0
	func _palm_cost(_states_input: Dictionary) -> float: return 0.0
	func _bone_crossings(_states_input: Dictionary,_id: StringName) -> int: return crossings
	func _target_normals(block: Array,_frames_input: Dictionary) -> Dictionary:
		var normals: Dictionary={}
		for index: int in block.size(): normals[index]=Vector3.BACK
		return normals
	func _query(_kind: StringName,points: PackedVector3Array) -> Dictionary:
		var gaps:=PackedFloat64Array(); var normals:=PackedVector3Array()
		for point: Vector3 in points: gaps.append(point.x); normals.append(physical_normal)
		return {"valid":true,"signed_distances":gaps,"normals":normals}

class PalmPlacementProbe extends Solver:
	var query_count:=0
	var largest_distance:=0.0
	func _frames(_states_input: Dictionary) -> Dictionary: return {}
	func _query(_kind: StringName,points: PackedVector3Array) -> Dictionary:
		query_count+=1
		var gaps:=PackedFloat64Array(); var normals:=PackedVector3Array()
		for point: Vector3 in points:
			largest_distance=maxf(largest_distance,point.length())
			gaps.append(point.length()-0.01); normals.append(point.normalized())
		return {"valid":true,"signed_distances":gaps,"normals":normals}

class AssessmentEntryProbe extends Solver:
	var assessment_calls:=0
	func _initialize_inputs(_resource: Resource,_stage_input: Dictionary,_config: Dictionary) -> Dictionary:
		var inputs: Dictionary={}; var angles: Dictionary={}
		for id: StringName in ALL_DIGITS:
			inputs[id]={"snapshot":{"min_angles_rad":[0.0,0.0,0.0],"max_angles_rad":[1.7,1.7,1.7]}}
			angles[id]=[0.0,0.0,0.0]
		_prepared={"adapter":{"digit_inputs":inputs},"open_angles":angles.duplicate(true)}
		return {"valid":true,"weapon":Transform3D.IDENTITY,"angles":angles}
	func _assess(angles: Dictionary) -> Dictionary:
		assessment_calls+=1
		return {"angles":angles.duplicate(true)}
	func _compose_final(angles: Dictionary,_best: Dictionary,_original: Transform3D,_started: int) -> Dictionary:
		return {"valid":true,"observed_angles":angles.duplicate(true)}

class BoneSlabProbe extends RefCounted:
	func intersects_segments(pairs: PackedVector3Array) -> PackedByteArray:
		var hits:=PackedByteArray()
		for pair: int in pairs.size()/2:
			var lower:=minf(pairs[pair*2].x,pairs[pair*2+1].x)
			var upper:=maxf(pairs[pair*2].x,pairs[pair*2+1].x)
			hits.append(1 if lower<0.0 and upper> -0.005 else 0)
		return hits

func _init() -> void:
	OS.add_logger(_errors)
	call_deferred("_run")

func _run() -> void:
	_depth_band()
	_section_caps()
	_transverse_ownership()
	_weighted_skin_algebra()
	_skin_cache_contract()
	_blended_triangle_normals()
	_effective_cap_deduplication()
	_shared_seat_fit()
	_thumb_seed_safety()
	_attraction_and_depth_witnesses()
	_prospective_contact_constraints()
	_rounded_range_endpoints()
	_lateral_palm_placement()
	_assessment_entry_contract()
	_warm_seed_angle_contract()
	_final_assessment()
	_bone_chain_not_skin_tip()
	var cancelled:=Solver.new()
	cancelled.configure_lifecycle(func()->bool: return true,Callable())
	var refused: Dictionary=cancelled.run(null,{}, {})
	_check(not refused.valid and refused.cancelled and not refused.material_safe,"cancelled solve cannot publish an accepted pose")
	var report: Dictionary={"schema":"surface_grip_final_pose_contract_v1","checks":_checks,"failures":_failures,
		"engine_errors":_errors.entries,"passed":_failures.is_empty() and _errors.entries.is_empty(),
		"supersedes":"surface_grip_reseating_contract_v1 removed projection/anchor-lock contracts",
		"live_solver_executed":false,"grip_success_asserted":false,
		"scope":"depth bands, production caps, transverse ownership, barycentric skin algebra, bounded whole-hand fitting, final safety and facing"}
	var path:="C:/WORKSPACE/test_artifacts/surface_grip_final_pose_contract_"+Time.get_datetime_string_from_system(true).replace(":","-")+".json"
	if FileAccess.file_exists(path): push_error("Refusing to overwrite verification report"); quit(1); return
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null: push_error("Cannot write verification report"); quit(1); return
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("SURFACE_GRIP_FINAL_POSE_CONTRACT ","PASS" if report.passed else "FAIL"," checks=",_checks," report=",path)
	quit(0 if report.passed else 1)

func _depth_band() -> void:
	var solver:=Solver.new()
	for cap: float in [0.005,0.0035,0.00108,0.00038]:
		for gap: float in [0.0,0.00001,-cap*0.5,-cap+0.000051,-cap-0.000003]:
			_check(not solver._at_max_contact_depth({"hit":true,"gap_m":gap},cap),"surface/shallow/overcap does not satisfy "+str(cap)+": "+str(gap))
		for gap: float in [-cap+0.000049,-cap,-cap-0.000001]:
			_check(solver._at_max_contact_depth({"hit":true,"gap_m":gap},cap),"measured near-cap depth qualifies "+str(cap)+": "+str(gap))
		for observed: Dictionary in [{},{"hit":false,"gap_m":-cap},{"hit":true},{"hit":true,"gap_m":INF},
				{"hit":true,"gap_m":NAN},{"hit":true,"gap_m":-cap,"depth_is_lower_bound":true}]:
			_check(not solver._at_max_contact_depth(observed,cap),"unmeasured/nonfinite/lower-bound depth cannot qualify "+str(observed))
	for cap: float in [0.0,-0.001,INF,-INF,NAN]:
		_check(not solver._at_max_contact_depth({"hit":true,"gap_m":-0.0035},cap),"invalid cap cannot qualify "+str(cap))

func _section_caps() -> void:
	var anatomy:=Anatomy.new()
	for side: String in ["L","R"]:
		var caps: Dictionary=anatomy._caps(&"hand_left" if side=="L" else &"hand_right")
		_check(caps.size()==15,side+" production caps cover all sections")
		for digit: String in ["Index","Mid","Ring","Pinky","Thumb"]:
			var expected: Array=[0.005,0.00108,0.00038] if digit=="Thumb" else [0.005,0.0035,0.0035]
			for j: int in 3:
				var bone:=StringName("CC_Base_%s_%s%d" % [side,digit,j+1])
				_check(caps.has(bone) and absf(float(caps.get(bone,INF))-float(expected[j]))<1e-9,String(bone)+" retains its configured physical allowance")

func _transverse_ownership() -> void:
	var solver:=Solver.new()
	for basis: Basis in [Basis.IDENTITY,Basis(Vector3(0.2,1,-0.3).normalized(),0.7)]:
		for sign: float in [-1.0,1.0]:
			var axis:=basis*Vector3.RIGHT*sign
			solver.set("_axis",axis)
			var original:=Transform3D(basis,Vector3(0.1,-0.2,0.3))
			var before:=var_to_bytes(original)
			var displacement: Vector3=solver._transverse(Vector3(0.03,-0.02,0.01))
			var translated:=original; translated.origin+=displacement
			_check(absf(displacement.dot(axis))<1e-7,"seat displacement preserves longitudinal station")
			_check(translated.basis==original.basis,"translation preserves authored weapon orientation exactly")
			_check(var_to_bytes(original)==before,"transverse proposal leaves input frame unchanged")
			_check(solver._transverse(axis*0.1).length()<1e-7,"pure axial request produces no allowed movement")

func _weighted_skin_algebra() -> void:
	var solver:=Solver.new()
	solver.set("_anatomy",PackedPoseProbe.new())
	var open_frames: Dictionary={&"A":Transform3D.IDENTITY,&"B":Transform3D(Basis(Vector3.RIGHT,0.3),Vector3(0.01,0,0)),&"C":Transform3D.IDENTITY}
	var vertices: Array=[]
	for i: int in 3:
		var wa:=0.6-0.2*i; var wb:=0.8-wa
		var a:=Vector3(0.01+i*0.002,0.02,0.003); var b:=Vector3(0.005,0.01+i*0.003,-0.002)
		vertices.append({"fixed_world":Vector3(0.001,-0.002,0.003),"moving":[
			{"bone":&"A","weighted_bind_point":a*wa,"weight":wa},
			{"bone":&"B","weighted_bind_point":b*wb,"weight":wb}]})
	solver.set("_prepared",{"vertices":vertices,"open_frames_world":open_frames,
		"references":{"wrist_world":Vector3.ZERO},"adapter":{"digit_inputs":{&"middle":{"snapshot":{"bone_names":[&"A",&"B",&"C"]}}}}})
	var source: Array=[{"vertex_ids":PackedInt32Array([0,1,2]),"barycentric":Vector3(0.2,0.3,0.5),"cap_m":0.0035,"digit":&"middle","section":2}]
	var before:=var_to_bytes([source,vertices])
	var block: Array=solver._pack_samples(source)
	var frames: Dictionary={&"A":Transform3D(Basis(Vector3.UP,0.6),Vector3(0.2,0.1,-0.1)),
		&"B":Transform3D(Basis(Vector3.RIGHT,-0.4),Vector3(-0.1,0.2,0.3))}
	var expected:=Vector3.ZERO
	for i: int in 3:
		var point: Vector3=vertices[i].fixed_world
		for influence: Dictionary in vertices[i].moving:
			point+=(frames[influence.bone] as Transform3D)*(influence.weighted_bind_point/float(influence.weight))*float(influence.weight)
		expected+=point*float(source[0].barycentric[i])
	for origin: Vector3 in [Vector3.ZERO,Vector3(0.4,-0.3,0.2)]:
		solver.set("_weapon",Transform3D(Basis(Vector3.UP,0.4),origin))
		var actual: PackedVector3Array=solver._points(block,frames)
		_check(actual.size()==1 and actual[0].distance_to(expected-origin)<0.000002,"packed barycentric skin equals independent weighted-vertex evaluation")
	_check(var_to_bytes([source,vertices])==before,"sample packing leaves source skin data unchanged")
	_check(block[0].normal_bone==&"B" and (open_frames[&"B"].basis*(block[0].normal as Vector3)).distance_to(Vector3.BACK)<1e-6,"section normal retains its named bone frame")
	var vertex_sample: Dictionary=source[0].duplicate(true)
	vertex_sample.barycentric=Vector3(1,0,0)
	var repeated: Array=[vertex_sample,vertex_sample.duplicate(true)]
	_check(solver._pack_samples(repeated).size()==1,"identical physical vertex and cap need one safety query")
	repeated[1].cap_m=0.001
	_check(solver._pack_samples(repeated).size()==2,"different overlap caps at the same vertex retain both guards")
	for sample: Dictionary in repeated: sample["target_section"]=1; sample.cap_m=0.0035
	_check(solver._pack_samples(repeated).size()==2,"attraction witnesses are not removed by safety deduplication")

func _skin_cache_contract() -> void:
	var solver:=Solver.new()
	var defaults: Dictionary={&"A":Transform3D(Basis(Vector3.UP,0.4),Vector3(0.2,-0.1,0.3))}
	var prepared: Dictionary={"open_frames_world":defaults}
	solver.set("_prepared",prepared)
	var origin:=Vector3(0.1,0.05,-0.2)
	solver.set("_weapon",Transform3D(Basis.IDENTITY,origin))
	var block: Array=[{"fixed":Vector3(0.01,0.02,0.03),"moving":{&"A":[Vector3(0.004,0.003,0.002),0.35]}},
		{"fixed":Vector3(0.07,-0.08,0.09),"moving":{}}]
	var before:=var_to_bytes(block)
	var expected: Vector3=block[0].fixed+defaults[&"A"].basis*block[0].moving[&"A"][0]+defaults[&"A"].origin*0.35-origin
	var actual: PackedVector3Array=solver._points(block,{})
	_check(actual.size()==2 and actual[0].distance_to(expected)<0.0000002,"native skinning falls back to prepared frames without normalizing weights")
	_check(actual[1].distance_to(block[1].fixed-origin)<0.0000002,"fixed-only carriers retain their exact affine contribution")
	var copy: Array=block.duplicate(true)
	copy[0].fixed+=Vector3(0.006,0,0)
	var duplicate_result: PackedVector3Array=solver._points(copy,{})
	_check(duplicate_result[0].distance_to(actual[0]+Vector3(0.006,0,0))<0.0000002,"equal-size distinct blocks do not alias cached native coefficients")
	block.append({"fixed":Vector3(0.3,0.2,0.1),"moving":{}})
	var appended: PackedVector3Array=solver._points(block,{})
	_check(appended.size()==3 and appended[2].distance_to(block[2].fixed-origin)<0.0000002,"appended guard witness refreshes native block cache")
	var revised: Dictionary=defaults.duplicate(true)
	revised[&"A"].origin+=Vector3(0.02,0.03,-0.01)
	prepared.open_frames_world=revised
	var refreshed: PackedVector3Array=solver._points(block,{})
	_check(refreshed[0].distance_to(actual[0]+Vector3(0.02,0.03,-0.01)*0.35)<0.0000002,"new default-frame dictionary invalidates cached bind frames")
	var override: Dictionary={&"A":Transform3D(Basis(Vector3.RIGHT,-0.7),Vector3(-0.2,0.4,0.1))}
	var overridden: PackedVector3Array=solver._points(block,override)
	expected=block[0].fixed+override[&"A"].basis*block[0].moving[&"A"][0]+override[&"A"].origin*0.35-origin
	_check(overridden[0].distance_to(expected)<0.0000002,"per-pose frames override defaults with old affine skinning algebra")
	_check(var_to_bytes(copy)!=before and var_to_bytes(block.slice(0,2))==before,"skinning cache leaves source coefficient dictionaries unchanged")

func _blended_triangle_normals() -> void:
	var solver:=Solver.new()
	solver.set("_anatomy",PackedPoseProbe.new())
	var rest: Array=[Vector3(-0.02,0,0),Vector3(0.02,0,0),Vector3(0,0.03,0)]
	var weights: Array=[1.0,0.2,0.6]
	var vertices: Array=[]
	for i: int in 3:
		vertices.append({"fixed_world":Vector3.ZERO,"moving":[
			{"bone":&"A","weighted_bind_point":rest[i]*weights[i],"weight":weights[i]},
			{"bone":&"B","weighted_bind_point":rest[i]*(1.0-weights[i]),"weight":1.0-weights[i]}]})
	var open: Dictionary={&"A":Transform3D.IDENTITY,&"B":Transform3D.IDENTITY,&"C":Transform3D.IDENTITY}
	solver.set("_prepared",{"vertices":vertices,"open_frames_world":open,"references":{"wrist_world":Vector3.ZERO},
		"adapter":{"digit_inputs":{&"middle":{"snapshot":{"bone_names":[&"A",&"B",&"C"]}}}}})
	var source: Array=[{"vertex_ids":PackedInt32Array([0,1,2]),"barycentric":Vector3(0.2,0.3,0.5),
		"cap_m":0.0035,"digit":&"middle","section":2,"target_section":1,"normal_sign":1.0}]
	var block: Array=solver._pack_samples(source)
	var frames: Dictionary={&"A":Transform3D(Basis(Vector3.RIGHT,0.8),Vector3(0.001,0.002,-0.003)),
		&"B":Transform3D(Basis(Vector3.UP,-0.5),Vector3(-0.002,0.001,0.004))}
	var corners: Array=[]
	for i: int in 3:
		corners.append((frames[&"A"] as Transform3D)*rest[i]*weights[i]+(frames[&"B"] as Transform3D)*rest[i]*(1.0-weights[i]))
	var expected: Vector3=(corners[1]-corners[0]).cross(corners[2]-corners[0]).normalized()
	var normal: Vector3=solver._target_normals(block,frames)[0]
	_check(normal.distance_to(expected)<0.00001,"target normal comes from the actually blended triangle corners")
	_check(normal.distance_to(frames[&"B"].basis*Vector3.BACK)>0.1,"blended triangle regression distinguishes the old single-bone normal")
	solver.set("_weapon",Transform3D(Basis(Vector3.UP,0.3),Vector3(0.4,-0.2,0.1)))
	_check((solver._target_normals(block,frames)[0] as Vector3).distance_to(expected)<0.00001,"weapon-origin translation cannot change posed skin facing")
	var reversed: Array=source.duplicate(true); reversed[0].normal_sign=-1.0
	_check((solver._target_normals(solver._pack_samples(reversed),frames)[0] as Vector3).distance_to(-expected)<0.00001,"anatomical orientation sign is retained on the exact posed normal")
	var block_with_guard: Array=block.duplicate(true)
	var guard: Dictionary=block[0].duplicate(true); guard.sample.erase("target_section"); block_with_guard.append(guard)
	_check(solver._target_normals(block_with_guard,frames).size()==1,"safety-only carriers do not become attraction-normal targets")

func _effective_cap_deduplication() -> void:
	var solver:=Solver.new()
	solver.set("_anatomy",BoundaryPoseProbe.new()); solver.set("_tangent",Vector3.RIGHT); solver.set("_outward",Vector3.BACK)
	var vertex: Dictionary={"fixed_world":Vector3(0.01,0.01,0.01),"moving":[]}
	solver.set("_prepared",{"vertices":[vertex,vertex,vertex],"open_frames_world":{},
		"references":{"wrist_world":Vector3.ZERO},"adapter":{"digit_inputs":{}}})
	var front: Dictionary={"vertex_ids":PackedInt32Array([0,1,2]),"barycentric":Vector3(1,0,0),"cap_m":0.0,"test_normal":Vector3.BACK}
	var back: Dictionary=front.duplicate(true); back.test_normal=Vector3.FORWARD
	for samples: Array in [[front,back,front.duplicate(true)],[back,front,back.duplicate(true)]]:
		var block: Array=solver._pack_samples(samples)
		var caps: Array=[]
		for carrier: Dictionary in block: caps.append(carrier.cap)
		_check(block.size()==2 and caps.has(0.0) and caps.has(0.0035),"incident-face order cannot drop the stricter effective overlap cap")

func _rounded_range_endpoints() -> void:
	for sign: float in [-1.0,1.0]:
		var probe:=_shared_plane_probe(sign)
		var lower: Array=[-1.7,-1.7,-1.7] if sign<0 else [0.0,0.0,0.0]
		var upper: Array=[0.0,0.0,0.0] if sign<0 else [1.7,1.7,1.7]
		var bound:=1.7*sign
		_check((Vector3(bound,bound,bound).x>bound) if sign>0 else (Vector3(bound,bound,bound).x<bound),"regression endpoint rounds outside the authoritative scalar range")
		for id: StringName in DIGITS:
			probe._prepared.adapter.digit_inputs[id].snapshot.min_angles_rad=lower
			probe._prepared.adapter.digit_inputs[id].snapshot.max_angles_rad=upper
		var fitter:=HandFit.new(); fitter._solver=probe; fitter._prepare()
		var values: Array=[]; values.resize(17); values.fill(rad_to_deg(bound)); values[15]=0.0; values[16]=0.0
		var pose: Dictionary=fitter._evaluate(values)
		for j: int in 3:
			_check(pose.angles[&"middle"][j]>=lower[j] and pose.angles[&"middle"][j]<=upper[j],"returned pose never crosses scalar ROM endpoints through Vector3 rounding")

func _lateral_palm_placement() -> void:
	# At a 20 mm lateral offset the old fixed-direction approach misses this
	# 10 mm radius target entirely and runs away after passing its near side.
	for basis: Basis in [Basis.IDENTITY,Basis(Vector3(0.3,1,0.2).normalized(),0.7)]:
		for offset: float in [-0.02,0.02]:
			var probe:=PalmPlacementProbe.new()
			var axis:=basis*Vector3.UP
			var palm_point:=axis*0.125
			var initial:=Transform3D(basis,palm_point)
			probe.set("_weapon",initial); probe.set("_axis",axis)
			probe.set("_tangent",basis*Vector3.RIGHT); probe.set("_outward",basis*Vector3.BACK)
			probe.set("_prepared",{"open_frames_world":{},"references":{"knuckle_midpoint_world":palm_point}})
			probe.set("_palm",[{"fixed":palm_point,"moving":{}}])
			probe._place_palm({},offset)
			var result: Transform3D=probe.get("_weapon")
			var final_gap:=palm_point.distance_to(result.origin)-0.01
			_check(absf(final_gap+0.0035-0.00005)<0.00005,"lateral palm approach converges to the requested depth instead of passing the target")
			_check(probe.largest_distance<0.153,"lateral miss cannot produce metre-scale runaway translation")
			_check(result.basis==initial.basis,"palm placement preserves authored weapon basis")
			_check(absf((result.origin-initial.origin).dot(axis))<0.0000001,"palm placement preserves longitudinal handle station")
			_check(probe.query_count<=56,"palm initialization retains bounded iteration and backtracking work")

func _assessment_entry_contract() -> void:
	var probe:=AssessmentEntryProbe.new()
	var states: Dictionary={}
	for id: StringName in DIGITS: states[id]={"angles_rad":[0.2,0.4,0.6]}
	var before:=var_to_bytes(states)
	var observed: Dictionary=probe.assess_final_pose(null,{}, {},states)
	_check(observed.valid and observed.assessment_only and probe.assessment_calls==1,"assessment-only API evaluates a supplied final pose once")
	_check(var_to_bytes(states)==before and observed.observed_angles[&"index"]==[0.2,0.4,0.6],"assessment keeps supplied angles and caller state unchanged")
	var rounded: Dictionary=states.duplicate(true); rounded[&"index"].angles_rad[0]=1.7000005
	var clamped: Dictionary=probe.assess_final_pose(null,{}, {},rounded)
	_check(clamped.valid and clamped.observed_angles[&"index"][0]==1.7,"assessment clamps only tolerated numerical ROM overshoot")
	for values: Array in [[0.1,0.2],[0.1,0.2,INF],[0.1,NAN,0.2],[0.1,1.7001,0.2],[-0.0001,0.2,0.3]]:
		var invalid: Dictionary=states.duplicate(true); invalid[&"ring"].angles_rad=values
		var calls_before:=probe.assessment_calls
		var refused: Dictionary=probe.assess_final_pose(null,{}, {},invalid)
		_check(not refused.valid and probe.assessment_calls==calls_before,"invalid supplied digit state cannot reach final geometry assessment")
	var reused:=Solver.new()
	var shared_frames: Dictionary={&"A":Transform3D.IDENTITY}
	var frames_before:=var_to_bytes(shared_frames)
	reused.set("_point_cache_frames",shared_frames)
	reused.set("_point_cache",[{"sentinel":true}]); reused.set("_normal_cache",[{"sentinel":true}])
	reused.set("_blocks",{&"old":[]}); reused.set("_kernels",{&"old":null}); reused.set("_repairing",true); reused.set("_thumb_active",true)
	var refused: Dictionary=reused._initialize_inputs(null,{}, {})
	_check(not refused.valid and var_to_bytes(shared_frames)==frames_before,"reinitialization never clears externally referenced prepared bone frames")
	_check((reused.get("_point_cache") as Array).is_empty() and (reused.get("_normal_cache") as Array).is_empty() and
		(reused.get("_blocks") as Dictionary).is_empty() and (reused.get("_kernels") as Dictionary).is_empty() and
		not reused.get("_repairing") and not reused.get("_thumb_active"),"reuse resets query caches and prior solve flags even when new inputs are rejected")

func _shared_plane_probe(sign: float) -> CoupledPlaneProbe:
	var probe:=CoupledPlaneProbe.new()
	var lower: Array=[-0.7,-0.7,-0.7] if sign<0 else [0.0,0.0,0.0]
	var upper: Array=[0.0,0.0,0.0] if sign<0 else [0.7,0.7,0.7]
	var inputs: Dictionary={}; var opened: Dictionary={}; var frames: Dictionary={}; var blocks: Dictionary={}; var guards: Array=[]
	for id: StringName in DIGITS:
		var names: Array=[StringName(String(id)+"A"),StringName(String(id)+"B"),StringName(String(id)+"C")]
		var snapshot: Dictionary={"min_angles_rad":lower.duplicate(),"max_angles_rad":upper.duplicate(),"bone_names":names,
			"relative_transforms":[Transform3D.IDENTITY,Transform3D.IDENTITY,Transform3D.IDENTITY],
			"neutral_local_rotations":[Quaternion.IDENTITY,Quaternion.IDENTITY,Quaternion.IDENTITY],
			"hinge_axes_local":[Vector3.BACK,Vector3.BACK,Vector3.BACK],"tip_offset_local":Vector3(0,0.02*sign,0)}
		inputs[id]={"snapshot":snapshot}; opened[id]=[0.0,0.0,0.0]
		var block: Array=[]
		for section: int in 3:
			frames[names[section]]=Transform3D.IDENTITY
			if id==&"thumb" and section==0: continue
			var cap:=0.005 if section==0 else 0.0035
			var goal: float=[0.35,0.5,0.6][section]
			# A stationary palm needs +9.45 mm weapon translation. The movable
			# digit carriers additionally need a coupled change of hinge angles.
			var carrier: Dictionary={"fixed":Vector3(0.02*sin(goal)-cap+0.00005+0.00945,0,0.03),
				"moving":{names[section]:[Vector3(0,0.02*sign,0),1.0]},"cap":cap,
				"sample":{"target_section":section,"bell":1.0,"percent":[20.0,50.0,60.0][section],
					"barycentric":Vector3(0.2,0.3,0.5),"vertex_ids":PackedInt32Array([0,1,2]),
					"triangle_id":section,"source_id":String(id)}}
			block.append(carrier); guards.append(carrier)
		blocks[id]=block
	var palm: Dictionary={"fixed":Vector3(0.006,0,0.03),"moving":{},"cap":0.0035,"sample":{}}
	guards.append(palm)
	probe._prepared={"adapter":{"digit_inputs":inputs},"open_angles":opened,"open_frames_world":frames}
	probe._metrics={"candidate_steps":0,"native_surface_queries":0}
	probe._blocks=blocks; probe._palm=[palm]; probe._safety=guards; probe._thumb_active=true
	probe._axis=Vector3.BACK; probe._tangent=Vector3.RIGHT; probe._outward=Vector3.UP
	return probe

func _warm_seed_angle_contract() -> void:
	var probe:=AssessmentEntryProbe.new()
	probe._initialize_inputs(null,{}, {})
	var states: Dictionary={}
	for id: StringName in DIGITS: states[id]={"angles_rad":[0.2,0.4,0.6]}
	var before:=var_to_bytes(states)
	var prepared_before:=var_to_bytes(probe._prepared)
	var checked: Dictionary=probe._validated_digit_angles(states)
	_check(checked.valid and checked.angles[&"middle"]==[0.2,0.4,0.6],"support warm seed preserves the supplied coherent finger angles")
	_check(var_to_bytes(states)==before and var_to_bytes(probe._prepared)==prepared_before,"warm seed validation leaves caller states and prepared open angles immutable")
	checked.angles[&"middle"][0]=1.0
	_check(var_to_bytes(states)==before and var_to_bytes(probe._prepared)==prepared_before,"validated warm angles do not alias source or prepared arrays")
	for invalid_values: Array in [[],[0.2,0.4],[0.2,0.4,INF],[0.2,NAN,0.4],[-0.01,0.4,0.6],[0.2,0.4,1.71]]:
		var invalid: Dictionary=states.duplicate(true); invalid[&"pinky"].angles_rad=invalid_values
		var rejected: Dictionary=probe.run(null,{}, {"seat_weapon":false,"seed_digit_states":invalid})
		_check(not rejected.valid and probe.assessment_calls==0,"malformed or illegal warm seed is refused before fixed-seat fitting")
	var missing: Dictionary=states.duplicate(true); missing.erase(&"thumb")
	_check(not probe._validated_digit_angles(missing).valid,"warm seed requires an explicit state for every active digit")
	var near_bound: Dictionary=states.duplicate(true); near_bound[&"index"].angles_rad[2]=1.7000005
	var clamped: Dictionary=probe._validated_digit_angles(near_bound)
	_check(clamped.valid and clamped.angles[&"index"][2]==1.7,"warm seed permits only existing sub-microradian bound rounding")
	for invalid_root: Variant in [null,1.0,"not states",[]]:
		_check(not probe._validated_digit_angles(invalid_root).valid,"malformed warm state root is rejected without coercion")
	for invalid_state: Variant in [null,1.0,"not a digit",[]]:
		var malformed: Dictionary=states.duplicate(true); malformed[&"ring"]=invalid_state
		_check(not probe._validated_digit_angles(malformed).valid,"malformed individual digit state is rejected without a script error")
	for invalid_angles: Variant in [null,1.0,"123",Vector3(0.2,0.4,0.6),[0.2,"0.4",0.6],[0.2,null,0.6]]:
		var malformed: Dictionary=states.duplicate(true); malformed[&"ring"].angles_rad=invalid_angles
		_check(not probe._validated_digit_angles(malformed).valid,"malformed angle container or element is rejected without numeric coercion")
	for packed: Variant in [PackedFloat32Array([0.2,0.4,0.6]),PackedFloat64Array([0.2,0.4,0.6])]:
		var accepted: Dictionary=states.duplicate(true); accepted[&"ring"].angles_rad=packed
		_check(probe._validated_digit_angles(accepted).valid,"finite packed floating-point angle inputs remain valid")

func _shared_seat_fit() -> void:
	for sign: float in [-1.0,1.0]:
		var probe:=_shared_plane_probe(sign)
		var original:=Transform3D(Basis(Vector3.BACK,0.47),Vector3(0,0,0.03))
		var angles: Dictionary={}
		for id: StringName in DIGITS: angles[id]=[0.05*sign,0.1*sign,0.1*sign]
		var seeds: Array=[{"weapon":original,"angles":angles}]
		var before:=var_to_bytes([seeds,probe._prepared])
		var fitted: Dictionary=HandFit.new().fit(probe,original,seeds,true)
		_check(fitted.valid,"shared analytic fixture produces a final assessment")
		if not fitted.valid: continue
		var assessment: Dictionary=fitted.assessment; var metrics: Dictionary=fitted.metrics
		_check(metrics.attraction_witnesses.size()==14,"optimizer reports all fourteen independently selected attraction witnesses")
		for witness: Dictionary in metrics.attraction_witnesses:
			_check(witness.selection==&"optimizer_weighted_contact_witness" and witness.vertex_ids==[0,1,2] and
				absf(float(witness.barycentric[0])-0.2)<0.000001,"attraction diagnostics retain source-triangle identity and their explicit selection role")
			_check(absf(float(witness.physical_closest_world[0])-assessment.weapon.origin.x)<0.000001,
				"diagnostic closest point lies on the independently translated physical plane")
		_check(metrics.evaluations<=161 and metrics.derivative_poses<=300,"one shared basin has bounded candidate and derivative work")
		_check(assessment.safe and assessment.max_excess_m<=0.000002,"shared final pose respects physical limits")
		_check(absf(assessment.palm_gap_m+0.00345)<0.0001,"weapon translation seats the independent fixed palm")
		_check(assessment.weapon.origin.x>0.009 and assessment.weapon.origin.x<0.010,"shared solve moves the weapon rather than moving the static hand root")
		_check(assessment.weapon.basis==original.basis and absf((assessment.weapon.origin-original.origin).dot(probe._axis))<0.0000001,"shared seat movement preserves authored orientation and longitudinal station")
		_check(assessment.engaged_sections.size()==14,"all synthetic digit pads engage the translated surface together")
		_check(float(fitted.angles[&"middle"][0])*sign>0.25,"shared solve also changes proximal finger curvature")
		for id: StringName in DIGITS:
			for angle: float in fitted.angles[id]: _check(angle*sign>=0.0 and angle*sign<=0.7,"shared fit retains mirrored anatomical ROM")
		for basin: Dictionary in metrics.traces:
			for step: Dictionary in basin.trace: _check(step.cost_after<step.cost_before or (step.safe and step.max_excess_m<=0.000002),"accepted shared moves lower merit or restore physical safety")
		_check(var_to_bytes([seeds,probe._prepared])==before,"shared optimization leaves input seeds and prepared character data unchanged")
		var fixed_probe:=_shared_plane_probe(sign)
		var fixed: Dictionary=HandFit.new().fit(fixed_probe,original,seeds,false)
		_check(fixed.valid and fixed.assessment.weapon==original,"support/fixed-weapon mode preserves the entire weapon frame exactly")
		_check(fixed.assessment.palm_gap_m>0.0059,"fixed-weapon solve cannot fake a palm seat by moving immutable skin")
	var cancelled:=_shared_plane_probe(1.0)
	cancelled.configure_lifecycle(func()->bool:return true,Callable())
	var initial: Dictionary={}
	for id: StringName in DIGITS: initial[id]=[0.05,0.1,0.1]
	var stopped: Dictionary=HandFit.new().fit(cancelled,Transform3D.IDENTITY,[{"weapon":Transform3D.IDENTITY,"angles":initial}],true)
	_check(not stopped.valid and cancelled._metrics.candidate_steps==0,"pre-cancelled shared fitting never evaluates or publishes a new pose")

func _thumb_seed_safety() -> void:
	var probe:=_shared_plane_probe(1.0)
	probe.poison_thumb_preshape=true
	var original:=Transform3D(Basis.IDENTITY,Vector3(0,0,0.03))
	var angles: Dictionary={}
	for id: StringName in DIGITS: angles[id]=[0.05,0.1,0.1]
	var seeds: Array=[{"weapon":original,"angles":angles}]
	var fitted: Dictionary=HandFit.new().fit(probe,original,seeds,true)
	_check(fitted.valid,"a colliding Thumb preshape does not discard the original safe hand seed")
	if not fitted.valid: return
	var choice: Dictionary=fitted.metrics.seed_choices[0]
	_check(choice.open_thumb.safe and not choice.thumb_preshape.safe and choice.thumb_preshape.bone_crossings==1,
		"regression fixture exposes a real legal-angle Thumb preshape collision")
	_check(choice.selected==&"open_thumb" and fitted.metrics.initial_candidates==1 and fitted.metrics.basins_fitted==1,
		"safe preexisting Thumb candidate is retained without adding solver basins")
	_check(fitted.assessment.safe,"seed selection cannot publish a physically unsafe final hand")

func _attraction_and_depth_witnesses() -> void:
	# A preferred central pad can drive motion while a different eligible point
	# supplies the section's deepest-contact certificate. Reports must not swap them.
	var probe:=_shared_plane_probe(1.0)
	var preferred: Dictionary=probe._blocks[&"middle"][1].duplicate(true)
	preferred.fixed=Vector3(-0.001,0.02,0.03); preferred.moving={}
	preferred.sample.percent=50.0; preferred.sample.bell=1.0
	preferred.sample.source_id="preferred_pad"
	var deepest: Dictionary=preferred.duplicate(true)
	deepest.fixed.x=-0.00346; deepest.sample.percent=95.0; deepest.sample.bell=0.0
	deepest.sample.source_id="deepest_pad"
	probe._blocks[&"middle"][1]=preferred; probe._blocks[&"middle"].append(deepest)
	var original:=Transform3D(Basis.IDENTITY,Vector3(0,0,0.03))
	var fitter:=HandFit.new()
	fitter._solver=probe; fitter._reference=original; fitter._move_seat=true; fitter._prepare()
	var angles: Dictionary={}
	for id: StringName in DIGITS: angles[id]=[0.0,0.0,0.0]
	var pose: Dictionary=fitter._evaluate(fitter._values(angles,original))
	fitter._best=pose
	var selected: Dictionary={}
	for witness: Dictionary in fitter._attraction_witnesses():
		if witness.section=="middle:S2": selected=witness
	var assessment: Dictionary=probe._assess(angles)
	var depth: Dictionary={}
	for section: Dictionary in assessment.sections:
		if section.get("section")==&"middle:S2": depth=section
	_check(selected.get("source_id")=="preferred_pad" and selected.get("percent")==50.0,
		"optimizer attraction report follows the scored biased witness")
	_check(depth.get("percent")==95.0 and depth.get("actual_target_hit",false),
		"strict-depth certificate independently identifies a deeper eligible point")
	_check(absf(float(selected.get("physical_gap_m",INF))+0.001)<0.000001 and
		absf(float(depth.get("gap_m",INF))+0.00346)<0.000001,
		"attraction and depth diagnostics retain distinct measured geometry")

func _carrier(gap: float,cap: float,section: int=-1) -> Dictionary:
	return {"fixed":Vector3(gap,0,0),"moving":{},"cap":cap,"normal":Vector3.BACK,"normal_bone":&"",
		"sample":{"target_section":section,"percent":50.0}}

func _prospective_contact_constraints() -> void:
	var fitter:=HandFit.new()
	var lower: Array[float]=[]; var upper: Array[float]=[]
	for index: int in 17: lower.append(-100.0); upper.append(100.0)
	fitter._lower=lower; fitter._upper=upper; fitter._move_seat=true
	var values: Array=[]; values.resize(17); values.fill(0.0)
	var h: Array=[]; h.resize(17*17); h.fill(0.0)
	var b: Array=[]; b.resize(17); b.fill(0.0)
	for index: int in 17: h[index*17+index]=1.0
	var guard: Array=[]; guard.resize(17); guard.fill(0.0); guard[0]=-1.0
	b[0]=2.0
	var model: Dictionary={"h":h,"b":b,"constraints":[{"jac":guard,"gap":0.5}]}
	var step: Array=fitter._solve(model,0.0001,values)
	_check(absf(float(step[0])-0.5)<0.000001,"a currently separated guard limits predicted movement before it penetrates")
	_check(fitter._constraint_passes<=40,"prospective constraint working set has bounded effort")
	# Equal metric costs desire hinge +2 and transverse seat +1. The physical
	# boundary x+y<=.5 requires BOTH variables to change, yielding (.75,-.25).
	guard=guard.duplicate(); guard[15]=-1.0; b[15]=1.0
	model.constraints=[{"jac":guard,"gap":0.5}]
	step=fitter._solve(model,0.0001,values)
	_check(absf(float(step[0])-0.75)<0.0001 and absf(float(step[15])+0.25)<0.0001,"shared contact constraint redistributes hinge and weapon motion together")
	_check(float(step[0])+float(step[15])<=0.500001,"coupled proposal remains on the permitted side of the future boundary")
	model.constraints.append({"jac":guard.duplicate(),"gap":0.5})
	var duplicate: Array=fitter._solve(model,0.0001,values)
	var finite:=true
	for value: float in duplicate: finite=finite and is_finite(value)
	_check(finite and absf(float(duplicate[0])-float(step[0]))<0.000001 and absf(float(duplicate[15])-float(step[15]))<0.000001,"duplicate physical witnesses remain finite and do not change the solution")
	fitter._move_seat=false
	var fixed: Array=fitter._solve(model,0.0001,values)
	_check(absf(float(fixed[15]))<0.000001 and absf(float(fixed[16]))<0.000001 and float(fixed[0])<=0.500001,"fixed-weapon ownership survives an active shared contact constraint")

func _final_assessment() -> void:
	var probe:=AssessmentProbe.new()
	probe.set("_thumb_active",true)
	probe.set("_prepared",{"open_frames_world":{}})
	var blocks: Dictionary={}; var angles: Dictionary={}
	for id: StringName in DIGITS:
		var block: Array=[]; angles[id]=[0.0,0.0,0.0]
		var caps: Array=[0.005,0.00108,0.00038] if id==&"thumb" else [0.005,0.0035,0.0035]
		for j: int in 3: block.append(_carrier(-float(caps[j]),caps[j],j))
		blocks[id]=block
	probe.set("_blocks",blocks); probe.set("_palm",[_carrier(-0.0035,0.0035)])
	probe.set("_safety",[_carrier(-0.0035,0.0035)])
	var fit: Dictionary=probe._assess(angles)
	_check(fit.safe and fit.contacts.size()==14 and fit.palm_contact,"four fingers plus thumb S2/S3 and palm meet measured depth and safety")
	_check(fit.engaged_sections.size()==14 and fit.palm_engaged,"maximum-depth contacts also count as physical engagement")
	_check(not fit.contacts.has(&"thumb:S1"),"thumb proximal section is a guard, not an attraction requirement")
	probe.physical_normal=Vector3.BACK
	_check(probe._assess(angles).contacts.is_empty(),"backside-facing points cannot qualify even at maximum depth")
	probe.physical_normal=Vector3.FORWARD
	probe.set("_palm",[_carrier(-0.001,0.0035)])
	_check(not probe._assess(angles).palm_contact,"shallow palm cannot satisfy final seating")
	probe.set("_palm",[_carrier(-0.0035,0.0035)])
	probe.set("_safety",[_carrier(-0.003503,0.0035)])
	var unsafe: Dictionary=probe._assess(angles)
	_check(not unsafe.safe and unsafe.safety.sample_count==1,"dense safety guard can reject otherwise qualified contacts")
	_check(not probe._better(unsafe,fit),"unsafe pose cannot replace a safe pose")
	probe.set("_safety",[_carrier(-0.0035,0.0035)]); probe.crossings=1
	_check(not probe._assess(angles).safe,"bone intersection rejects final skin-only contact success")
	probe.crossings=0; blocks=blocks.duplicate(true); blocks[&"middle"][1]=_carrier(0.0,0.0035,1); probe.set("_blocks",blocks)
	var shallow: Dictionary=probe._assess(angles)
	_check(shallow.contacts.size()==13 and not shallow.contacts.has(&"middle:S2"),"surface-touching S2 remains unresolved while other sections stay qualified")
	_check(shallow.engaged_sections.size()==14 and shallow.engaged_sections.has(&"middle:S2"),"surface-touching section is physically engaged without claiming maximum depth")
	var floating: Dictionary=fit.duplicate(true); floating.palm_engaged=false; floating.cost=0.0
	var seated: Dictionary=fit.duplicate(true); seated.palm_engaged=true; seated.cost=1000.0
	_check(probe._better(seated,floating) and not probe._better(floating,seated),"safe seated palm outranks a cheaper floating-palm pose")
	seated.safe=false
	_check(not probe._better(seated,floating),"palm preference never overrides physical safety")

func _bone_chain_not_skin_tip() -> void:
	var solver:=Solver.new()
	solver.set("_kernels",{&"physical":BoneSlabProbe.new()})
	var state: Dictionary={"joint_origins_world":[Vector3(0.03,0,0),Vector3(0.02,0,0),Vector3(0.01,0,0)],
		"tip_world":Vector3(-0.001,0,0)}
	_check(solver._bone_crossings({&"middle":state},&"middle")==0,"permitted skin-tip penetration is not treated as a fabricated terminal bone crossing")
	state.joint_origins_world[1]=Vector3(-0.001,0,0)
	_check(solver._bone_crossings({&"middle":state},&"middle")>0,"real proximal joint-to-joint segments retain their physical crossing guard")

func _check(value: bool,label: String) -> void:
	_checks+=1
	if not value: _failures.append(label); push_error(label)
