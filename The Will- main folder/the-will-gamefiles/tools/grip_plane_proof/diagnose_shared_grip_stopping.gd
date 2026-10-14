extends SceneTree

## Read-only replay of seed ranking and one local model at a frozen result.
const Solver=preload("res://runtime/player/grip/surface_driven_grip_solver.gd")
const HandFit=preload("res://runtime/player/grip/surface_grip_hand_fit.gd")
const SeatFit=preload("res://runtime/player/grip/surface_grip_seat_fit.gd")
const Source=preload("res://runtime/player/grip/saved_wrapper_grip_source.gd")
const MANIFEST="C:/WORKSPACE/test_artifacts/grip_frozen_inputs_20261007_new_six/manifest.json"
const DEFAULT_INPUT="C:/WORKSPACE/test_artifacts/grip_frozen_inputs_20261007_new_six/06_handle_6_hand_right.bin"
const DEFAULT_RESULT="C:/WORKSPACE/test_artifacts/grip_finalfit_v14_constraints_all6/06_handle_6_hand_right_result.bin"

func _init()->void: call_deferred("_run")

func _run()->void:
	var input_path:=OS.get_environment("THE_WILL_GRIP_SHARED_DIAG_INPUT")
	var result_path:=OS.get_environment("THE_WILL_GRIP_SHARED_DIAG_RESULT")
	if input_path.is_empty(): input_path=DEFAULT_INPUT
	if result_path.is_empty(): result_path=DEFAULT_RESULT
	input_path=input_path.replace("\\","/").simplify_path(); result_path=result_path.replace("\\","/").simplify_path()
	if not input_path.begins_with("C:/WORKSPACE/") or not result_path.begins_with("C:/WORKSPACE/"):
		push_error("Diagnostic paths must remain in workspace"); quit(1); return
	var output_path:=result_path.get_basename()+"_shared_stopping.json"
	if FileAccess.file_exists(output_path): push_error("Refusing to replace diagnostic"); quit(1); return
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var fixture: Dictionary={}
	for row: Dictionary in manifest.fixtures:
		if row.input_path==input_path: fixture=row
	if fixture.is_empty() or FileAccess.get_sha256(input_path)!=fixture.sha256:
		push_error("Frozen input provenance mismatch"); quit(1); return
	var input:=_read(input_path); var result:=_read(result_path)
	if not result.get("valid",false) or FileAccess.get_sha256(input.source_library)!=input.source_library_sha256:
		push_error("Result/library provenance invalid"); quit(1); return
	var library: Resource=load(input.source_library)
	var stage2: Resource
	for item: Resource in library.get("saved_wips"):
		if str(item.get("forge_project_name"))==input.weapon_name: stage2=item.get("stage2_item_state")
	var stage: Dictionary=input.stage.duplicate(true)
	var source:=Source.from_stage2(stage2,stage.saved_grip_source.source_to_weapon)
	if not source.get("valid",false) or source.source_body_signature!=input.input_body_signature:
		push_error("Saved source mismatch"); quit(1); return
	stage.saved_grip_source=source
	var profile: Resource=load(input.anatomy_profile)
	var solver:=Solver.new()
	var setup:=solver._initialize_inputs(profile.get("anatomy"),stage,input.config)
	if not setup.get("valid",false): push_error("Initialization failed: "+str(setup)); quit(1); return
	var helper:=HandFit.new()
	helper._solver=solver; helper._reference=setup.weapon; helper._move_seat=true; helper._prepare()
	var angles: Dictionary={}
	for digit: StringName in Solver.ALL_DIGITS: angles[digit]=result.candidate.digit_states[digit].angles_rad.duplicate()
	solver._thumb_active=true
	var final:=helper._evaluate(helper._values(angles,result.selected.weapon_to_world))
	var baseline:=_describe(final,helper)
	var model:=helper._model(final)
	var trials: Array=[]
	for damping: float in [0.00000001,0.0001,0.01]:
		var raw:=helper._solve(model,damping,final.values)
		var move:=helper._bounded_step(raw.duplicate(),final.values)
		var minimum_prediction:=INF
		var predicted_failures:=0
		for constraint: Dictionary in model.constraints:
			var gap:=float(constraint.gap)+helper._dot(constraint.jac,move)
			minimum_prediction=minf(minimum_prediction,gap)
			if gap < -0.000001: predicted_failures+=1
		for fraction: float in [1.0,0.5,0.25,0.125,0.0625,0.03125]:
			var values: Array=final.values.duplicate()
			for variable: int in HandFit.VARIABLES: values[variable]+=float(move[variable])*fraction
			var pose:=helper._evaluate(values)
			trials.append({"damping":damping,"fraction":fraction,"move_degrees_mm":move,
				"constraint_passes":helper._constraint_passes,"active_constraints":helper._active_constraints,
				"predicted_violations":predicted_failures,"minimum_predicted_clearance_mm":minimum_prediction,
				"merit_improves":pose.cost<final.cost-0.000001,"description":_describe(pose,helper)})
	# Compare identical seated preshapes with open versus preseeded Thumb.
	solver._thumb_active=false
	var seeds:=SeatFit.new().make_candidates(solver,setup.weapon,setup.angles)
	solver._thumb_active=true
	var initial: Array=[]
	for index: int in seeds.size():
		var seeded: Dictionary=seeds[index].angles.duplicate(true)
		var open_thumb:=helper._evaluate(helper._values(seeded,seeds[index].weapon))
		helper._seed_thumb(seeded,index)
		var preseeded:=helper._evaluate(helper._values(seeded,seeds[index].weapon))
		initial.append({"index":index,"preshape_degrees":seeds[index].preshape_degrees,
			"offset_m":seeds[index].initial_tangent_offset_m,
			"open_thumb":_describe(open_thumb,helper),"preseeded_thumb":_describe(preseeded,helper)})
	var output:={"input_path":input_path,"input_sha256":fixture.sha256,"result_path":result_path,
		"result_sha256":FileAccess.get_sha256(result_path),"baseline":baseline,"local_trials":trials,
		"initial_candidates":initial,"solve_executed":false,"scene_modified":false,
		"input_unchanged":fixture.sha256==FileAccess.get_sha256(input_path)}
	var file:=FileAccess.open(output_path,FileAccess.WRITE)
	if file==null: push_error("Cannot write diagnostic"); quit(1); return
	file.store_string(JSON.stringify(output,"\t")); file.close()
	print("SHARED_GRIP_STOPPING_DIAGNOSTIC ",output_path)
	quit(0)

func _describe(pose: Dictionary,helper: RefCounted)->Dictionary:
	helper._best=pose
	var guards: Array=[]
	for index: int in helper._block.size():
		var carrier: Dictionary=helper._block[index]
		var clearance:=float(pose.physical.signed_distances[index])+float(carrier.cap)
		if clearance > 0.0005: continue
		guards.append({"clearance_m":clearance,"cap_m":carrier.cap,"physical_gap_m":pose.physical.signed_distances[index],
			"index":index,"sample":carrier.sample})
	guards.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.clearance_m<b.clearance_m)
	return {"cost":pose.cost,"safe":pose.safe,"max_excess_m":pose.max_excess_m,
		"bone_crossings":pose.bone_crossings,"palm_gap_m":pose.palm_gap_m,
		"angles_degrees_and_seat_mm":pose.values,"witnesses":helper._attraction_witnesses(),
		"closest_guards":guards.slice(0,12)}

func _read(path: String)->Dictionary:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:return {}
	var data: Dictionary=file.get_var(false); file.close(); return data
