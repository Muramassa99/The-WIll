extends SceneTree

## Reassess one frozen final pose, then inspect existing skin carriers. No fit,
## geometry regeneration, ownership change or live scene application occurs.
const Solver=preload("res://runtime/player/grip/surface_driven_grip_solver.gd")
const Source=preload("res://runtime/player/grip/saved_wrapper_grip_source.gd")
const Side=preload("res://runtime/player/grip/prepared_digit_gripping_surface.gd")
const INPUT:="C:/WORKSPACE/test_artifacts/grip_frozen_inputs_20261007_new_six/01_Handle_1_hand_right.bin"
const INPUT_SHA:="d9087b7171b82834e8ae569bc9ebdd97176afd6bbfd9816a3a78a8565b1fa1ca"
const DEFAULT_RESULT:="C:/WORKSPACE/test_artifacts/grip_finalfit_v9_margin_handle1/01_Handle_1_hand_right_result.bin"
class NoSearch extends Solver:
	var forbidden_search_calls:=0
	func run(_anatomy_resource: Resource,_stage_input: Dictionary,_config_input: Dictionary) -> Dictionary:
		forbidden_search_calls+=1; return {"valid":false,"reason":"unexpected_optimization"}
	func _fit_digit(_id: StringName,angles: Dictionary,_quick: bool) -> Dictionary:
		forbidden_search_calls+=1; return {"angles":angles,"cost":INF}
	func _place_palm(_states_input: Dictionary,_offset: float) -> void:
		forbidden_search_calls+=1
class Errors extends Logger:
	var entries: Array=[]
	func _log_error(function: String,file: String,line: int,code: String,rationale: String,_notify: bool,kind: int,_traces: Array[ScriptBacktrace]) -> void:
		if kind!=Logger.ERROR_TYPE_WARNING: entries.append({"function":function,"file":file,"line":line,"code":code,"rationale":rationale})
var errors:=Errors.new()
func _init() -> void:
	OS.add_logger(errors); call_deferred("_run")
func _run() -> void:
	var path:=OS.get_environment("THE_WILL_GRIP_PALM_RESULT")
	if path.is_empty(): path=DEFAULT_RESULT
	if not path.replace("\\","/").to_lower().begins_with("c:/workspace/") or FileAccess.get_sha256(INPUT)!=INPUT_SHA:
		push_error("Invalid result/input provenance"); quit(1); return
	var input:=_read(INPUT); var recorded:=_read(path)
	if input.is_empty() or not recorded.get("valid",false) or FileAccess.get_sha256(input.source_library)!=input.source_library_sha256:
		push_error("Missing valid immutable fixture"); quit(1); return
	var result_hash:=FileAccess.get_sha256(path)
	var library: Resource=load(input.source_library)
	var stage2: Resource
	for item: Resource in library.get("saved_wips"):
		if str(item.get("forge_project_name"))==input.weapon_name: stage2=item.get("stage2_item_state")
	var stage: Dictionary=input.stage.duplicate(true)
	var source:=Source.from_stage2(stage2,stage.saved_grip_source.source_to_weapon)
	if not source.get("valid",false) or source.source_body_signature!=input.input_body_signature:
		push_error("Source mismatch"); quit(1); return
	stage.saved_grip_source=source; stage.object.weapon_to_world=recorded.selected.weapon_to_world
	var profile: Resource=load(input.anatomy_profile)
	var input_before:=var_to_bytes([stage,recorded.candidate.digit_states])
	var solver:=NoSearch.new()
	var assessment:=solver.assess_final_pose(profile.get("anatomy"),stage,input.config,recorded.candidate.digit_states)
	if not assessment.get("valid",false): push_error("Recorded final pose cannot be assessed: "+str(assessment)); quit(1); return
	var contracts: Dictionary={"assessment_only":assessment.get("assessment_only",false),
		"no_optimization":solver.forbidden_search_calls==0,"input_unchanged":input_before==var_to_bytes([stage,recorded.candidate.digit_states]),
		"candidate_valid":assessment.candidate.get("valid",false),"all_five_digits":assessment.candidate.digit_states.size()==5,
		"weapon_unchanged":assessment.selected.weapon_to_world==stage.object.weapon_to_world,
		"hand_not_translated":assessment.candidate.translation_world==Vector3.ZERO,
		"method_contract":assessment.method==&"surface_contact_v6","material_assessed":assessment.material_assessed,
		"production_unwritten":not assessment.production_pose_written,"sample_scope_honest":not assessment.actual_3d_grip_verified}
	var prepared: Dictionary=solver.get("_prepared")
	var angles: Dictionary={}
	for id: StringName in Solver.ALL_DIGITS: angles[id]=recorded.candidate.digit_states[id].angles_rad
	var frames: Dictionary=solver._frames(solver._states(angles))
	var dense_palm: Array=[]
	for sample: Dictionary in prepared.safety_samples:
		if sample.get("palm_owned",false): dense_palm.append(sample)
	var selected_rows:=_query_rows(solver,solver.get("_palm"),frames)
	var dense_rows:=_query_rows(solver,solver._pack_samples(dense_palm),frames)
	var all_rows:=_query_rows(solver,solver.get("_safety"),frames)
	all_rows.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return a.remaining_allowance_m<b.remaining_allowance_m)
	var thumb_zero: Array=[]
	for row: Dictionary in all_rows:
		if row.sample.get("digit",&"")==&"thumb" and int(row.sample.get("section",0))==2 and row.cap_m==0.0: thumb_zero.append(row)
	var side:=Side.new().prepare(prepared.adapter,&"thumb")
	for row: Dictionary in thumb_zero.slice(0,8):
		var sample: Dictionary=row.sample; var ids: PackedInt32Array=sample.vertex_ids; var bary: Vector3=sample.barycentric
		if side.get("valid",false):
			var values: PackedFloat64Array=side.section_reference_sides_m[1]
			row["reference_closing_side_m"]=values[ids[0]]*bary.x+values[ids[1]]*bary.y+values[ids[2]]*bary.z
		var posed: Array=solver.get("_anatomy").pose_samples(prepared,[sample],frames)
		row["posed_skin_normal_world"]=posed[0].normal_world
		row["physical_facing_dot"]=(posed[0].normal_world as Vector3).dot(row.physical_normal_world)
	var old_frames: Dictionary=prepared.open_frames_world
	var frames_before:=var_to_bytes(old_frames)
	solver._initialize_inputs(null,{}, {})
	contracts["reuse_preserves_prior_prepared_frames"]=frames_before==var_to_bytes(old_frames)
	var output:={"schema":"recorded_final_grip_palm_coverage_v1","source_result":path,"source_result_sha256":result_hash,
		"input_sha256":INPUT_SHA,"assessment_contracts":contracts,"engine_errors":errors.entries,"solver_search_run":false,
		"selected_palm":_range(selected_rows),"dense_identified_palm":_range(dense_rows),
		"nearest_guard_boundaries":all_rows.slice(0,15),"thumb_s2_zero_cap_nearest":thumb_zero.slice(0,8),
		"reassessed_sections":assessment.totals.final_sections,"reassessed_material_validation":assessment.material_validation,
		"source_unchanged":result_hash==FileAccess.get_sha256(path) and INPUT_SHA==FileAccess.get_sha256(INPUT)}
	var output_path:=path.get_basename()+"_palm_coverage.json"
	if FileAccess.file_exists(output_path): push_error("Refusing to overwrite diagnostic"); quit(1); return
	var file:=FileAccess.open(output_path,FileAccess.WRITE)
	if file==null: push_error("Cannot write diagnostic"); quit(1); return
	file.store_string(JSON.stringify(output,"\t")); file.close()
	var passed:=errors.entries.is_empty() and not contracts.values().has(false)
	print("FINAL_GRIP_PALM_COVERAGE ",output_path," contracts=",contracts.size()," passed=",passed)
	quit(0 if passed else 1)
func _query_rows(solver: RefCounted,block: Array,frames: Dictionary) -> Array:
	var points: PackedVector3Array=solver._points(block,frames)
	var query: Dictionary=solver._query(&"physical",points)
	var rows: Array=[]
	for i: int in block.size():
		rows.append({"gap_m":query.signed_distances[i],"cap_m":block[i].cap,
			"remaining_allowance_m":float(query.signed_distances[i])+float(block[i].cap),
			"physical_normal_world":query.normals[i],"point_world":points[i]+(solver.get("_weapon") as Transform3D).origin,
			"sample":block[i].sample})
	return rows
func _range(rows: Array) -> Dictionary:
	if rows.is_empty(): return {"count":0}
	rows.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return a.gap_m<b.gap_m)
	var engaged:=0
	for row: Dictionary in rows:
		if row.gap_m<=0.00005 and row.gap_m>=-row.cap_m-0.000002: engaged+=1
	return {"count":rows.size(),"min_gap_m":rows[0].gap_m,"max_gap_m":rows[-1].gap_m,
		"engaged_samples":engaged,"deepest":rows[0],"shallowest":rows[-1]}
func _read(path: String) -> Dictionary:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null: return {}
	var output: Dictionary=file.get_var(false); file.close(); return output
