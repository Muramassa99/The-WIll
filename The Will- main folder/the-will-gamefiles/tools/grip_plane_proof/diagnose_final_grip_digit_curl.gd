extends SceneTree

## Evaluate a small explicit set of alternate Index/Ring curls against an
## existing result. No solver search, scene application, or source mutation.
const Solver = preload("res://runtime/player/grip/surface_driven_grip_solver.gd")
const Anatomy = preload("res://runtime/player/grip/prepared_surface_grip_anatomy.gd")
const Surface = preload("res://runtime/player/grip/grip_surface_query.gd")
const Source = preload("res://runtime/player/grip/saved_wrapper_grip_source.gd")
const INPUT := "C:/WORKSPACE/test_artifacts/grip_frozen_inputs_20261007_new_six/01_Handle_1_hand_right.bin"
const INPUT_SHA := "d9087b7171b82834e8ae569bc9ebdd97176afd6bbfd9816a3a78a8565b1fa1ca"
const DEFAULT_RESULT := "C:/WORKSPACE/test_artifacts/grip_finalfit_v4_handle1/01_Handle_1_hand_right_result.bin"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var path:=OS.get_environment("THE_WILL_GRIP_CURL_RESULT")
	if path.is_empty(): path=DEFAULT_RESULT
	path=path.replace("\\","/").simplify_path()
	if not path.begins_with("C:/WORKSPACE/") or FileAccess.get_sha256(INPUT)!=INPUT_SHA:
		push_error("Curl diagnostic input path/provenance invalid"); quit(1); return
	var input:=_read(INPUT)
	var result:=_read(path)
	if input.is_empty() or not result.get("valid",false): push_error("Missing valid input/result"); quit(1); return
	if FileAccess.get_sha256(input.source_library)!=input.source_library_sha256:
		push_error("Saved library changed"); quit(1); return
	var result_hash:=FileAccess.get_sha256(path)
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
	var prepared:=Anatomy.new().prepare(profile.get("anatomy"),stage,input.config)
	var surface:=Surface.prepare(source,input.config)
	if not prepared.get("valid",false) or not surface.get("valid",false):
		push_error("Prepared geometry unavailable"); quit(1); return
	var solver:=Solver.new()
	solver.set("_prepared",prepared); solver.set("_surface",surface)
	solver.set("_metrics",{"candidate_steps":0,"native_surface_queries":0})
	solver.set("_weapon",result.selected.weapon_to_world)
	var axis: Vector3=(stage.object.weapon_to_world.basis*(stage.object.primary_grip_span_end_local-stage.object.primary_grip_span_start_local)).normalized()
	solver.set("_axis",axis); solver.set("_pivot",stage.object.grip_pivot_local)
	var outward: Vector3=solver._transverse(prepared.references.palmar_out_world).normalized()
	var tangent:=axis.cross(outward).normalized()
	if tangent.dot(prepared.references.knuckle_midpoint_world-prepared.references.wrist_world)<0: tangent=-tangent
	solver.set("_outward",outward); solver.set("_tangent",tangent)
	var built: Dictionary=solver._prepare_kernels(source)
	if not built.get("valid",false): push_error("Native geometry unavailable: "+str(built)); quit(1); return
	solver.set("_palm",solver._pack_samples(prepared.palm_samples))
	solver.set("_safety",solver._pack_samples(prepared.safety_samples))
	var blocks: Dictionary={}; var original: Dictionary={}
	for id: StringName in Solver.ALL_DIGITS:
		var samples: Array=[]
		for section: int in 3:
			for sample: Dictionary in prepared.digits[id].sections[section].samples:
				var tagged:=sample.duplicate(); tagged.target_section=section; samples.append(tagged)
		samples.append_array(prepared.digits[id].safety_samples)
		blocks[id]=solver._pack_samples(samples)
		original[id]=result.candidate.digit_states[id].angles_rad.duplicate()
	solver.set("_blocks",blocks); solver.set("_thumb_active",true)
	var observations: Array=[]
	var started:=Time.get_ticks_usec()
	for id: StringName in [&"index",&"ring"]:
		var variants: Array=[{"label":"existing","angles":original[id].duplicate()}]
		for degrees: Vector3 in [Vector3(65,70,50),Vector3(70,85,55),Vector3(60,70,45)]:
			variants.append({"label":"proposed_degrees_"+str(degrees),"angles":[deg_to_rad(degrees.x),deg_to_rad(degrees.y),deg_to_rad(degrees.z)]})
		for j: int in 3:
			for change: float in [-10.0,10.0]:
				var values: Array=original[id].duplicate(); values[j]+=deg_to_rad(change)
				variants.append({"label":"joint%d_%+d_degrees" % [j+1,change],"angles":values})
		var snapshot: Dictionary=prepared.adapter.digit_inputs[id].snapshot
		for variant: Dictionary in variants:
			var angles: Dictionary=original.duplicate(true)
			var values: Array=variant.angles.duplicate()
			for j: int in 3: values[j]=clampf(values[j],snapshot.min_angles_rad[j],snapshot.max_angles_rad[j])
			angles[id]=values
			solver.set("_repairing",false)
			var cost: float=solver._digit_cost(id,angles)
			var assessed: Dictionary=solver._assess(angles)
			solver.set("_repairing",true)
			var repair_cost: float=solver._digit_cost(id,angles)
			var sections: Array=[]
			for section: Dictionary in assessed.sections:
				if String(section.get("section","")).begins_with(String(id)+":"): sections.append(section)
			observations.append({"digit":id,"label":variant.label,"angles_rad":values,"requested_angles_rad":variant.angles,
				"digit_cost":cost,"repair_digit_cost":repair_cost,"whole_hand_cost":assessed.cost,
				"safe":assessed.safe,"safety":assessed.safety,"palm_gap_m":assessed.palm_gap_m,
				"digit_bone_crossings":solver._bone_crossings(solver._states(angles),id),"sections":sections})
	var output:={"schema":"final_grip_explicit_curl_candidates_v1","source_result":path,"source_result_sha256":result_hash,
		"input_path":INPUT,"input_sha256":INPUT_SHA,"weapon_name":input.weapon_name,
		"candidates":observations,"evaluation_ms":(Time.get_ticks_usec()-started)/1000.0,
		"solver_search_run":false,"live_pose_modified":false,"weapon_and_other_digits_fixed":true,
		"source_unchanged":result_hash==FileAccess.get_sha256(path) and INPUT_SHA==FileAccess.get_sha256(INPUT)}
	var output_path:=path.get_basename()+"_curl_diagnostic.json"
	if FileAccess.file_exists(output_path): push_error("Refusing to overwrite curl diagnostic"); quit(1); return
	var file:=FileAccess.open(output_path,FileAccess.WRITE)
	if file==null: push_error("Cannot write curl diagnostic"); quit(1); return
	file.store_string(JSON.stringify(output,"\t")); file.close()
	print("FINAL_GRIP_CURL_DIAGNOSTIC ",output_path," candidates=",observations.size()," ms=",output.evaluation_ms)
	quit(0)

func _read(path: String) -> Dictionary:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null: return {}
	var result: Dictionary=file.get_var(false); file.close(); return result
