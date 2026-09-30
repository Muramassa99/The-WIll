extends "res://tools/grip_plane_proof/run_native_envelope_follow_proof.gd"

## Isolated controller: preparation -> material contact -> fixed-guide reseat.
## Numerical candidates are not committed gameplay poses or certified motion.
const Progression = preload("res://tools/grip_plane_proof/planar_grip_guide_progression.gd")
const PalmRegion = preload("res://tools/grip_plane_proof/prepared_palmar_slice_region.gd")
const CONFIG_PATH := "C:/WORKSPACE/test_artifacts/contact_envelope_input_2026-09-26.json"
const MAX_RESEATS: int = 3
const MIN_MATERIAL_SECTIONS: int = 3
const PREP_ITERATIONS: int = 12
const CONTACT_ITERATIONS: int = 24
var _config: Dictionary = {}
var _progression := Progression.new()
var _palm := PalmRegion.new()
var _depth := Depth.new()
var _guide_phase: String = "circle"
var _guide_amount: float = 0.0
var _fixed_guides: Dictionary = {}
var _frozen_parameters: Array = []
var _guide_preparation_cache: Dictionary = {}
var _response_runs: Array = []
var _reseat_attempts: Array = []
var _preserve_guide: Array = []
var _preserve_material: Array = []
var _path_checks: int = 0

func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not parsed is Dictionary or parsed.get("schema")!="contact_envelope_input_v1":
		push_error("Missing measured envelope configuration"); quit(1); return
	for field: String in ["measured_radius_m","envelope_radius_multiplier","envelope_radius_m"]:
		if not parsed.get(field) is float or not is_finite(parsed[field]) or parsed[field]<=0.0:
			push_error("Invalid envelope configuration"); quit(1); return
	if absf(parsed.measured_radius_m*parsed.envelope_radius_multiplier-parsed.envelope_radius_m)>1e-12:
		push_error("Envelope multiplier mismatch"); quit(1); return
	var measurement: String = str(parsed.get("measurement","")).replace("\\","/").simplify_path()
	if not measurement.begins_with("C:/WORKSPACE/test_artifacts/") or FileAccess.get_sha256(measurement)!=parsed.get("measurement_sha256"):
		push_error("Envelope measurement source mismatch"); quit(1); return
	_config=parsed
	await super._run()

func _report_stem() -> String:
	return "handle_grip_process"

func _report_extensions() -> Dictionary:
	return {"schema":"handle_grip_process_proof_v1","scope":"isolated_middle_thumb_and_conservative_palmar_core" if _selected_digits() == DIGITS else "isolated_selected_digits_and_conservative_palmar_core",
		"solver":"prescribed_guide_native_CCD_proposals_simultaneous_actual_skin_response",
		"minimum_actual_material_sections":MIN_MATERIAL_SECTIONS,"maximum_reseat_attempts":MAX_RESEATS,
		"guide_contact_band_m":CONTACT_BAND_M,"material_contact_numeric_guard_m":NUMERIC_GUARD_M,
		"guide_center_policy":"current_weapon_slice_area_centroid_in_each_digit_plane",
		"preparation_contact_failure_stops_shrinking":false,"radius_is_optimization_variable":false,
		"palm_overlap_cap_m":0.0025,"complete_palm_partition_verified":false,
		"palm_overlap_policy_applied":true,"palm_policy_scope":"conservatively_attributed_palmar_core_only",
		"envelope_inward_min_radius_m":_config.envelope_radius_m,
		"envelope_configuration_sha256":FileAccess.get_sha256(CONFIG_PATH),
		"reseat_policy":"freeze_guide_and_hand_planes_adjust_six_hinges_preserve_acquired_contacts" if _selected_digits() == DIGITS else "freeze_guide_and_hand_planes_adjust_selected_digit_hinges_preserve_acquired_contacts",
		"reseat_path_max_joint_step_rad":deg_to_rad(0.25),"continuous_sweep_certified":false,
		"material_flesh_give_source":"live_per_section_digit_rules",
		"source_sha256":{
			"runner":FileAccess.get_sha256(get_script().resource_path),
			"controller":FileAccess.get_sha256("res://runtime/player/grip/handle_grip_acquisition.gd"),
			"progression":FileAccess.get_sha256("res://runtime/player/grip/planar_grip_guide_progression.gd"),
			"palm":FileAccess.get_sha256("res://runtime/player/grip/prepared_palmar_slice_region.gd"),
			"skin":FileAccess.get_sha256("res://runtime/player/grip/prepared_hand_candidate_pose.gd"),
			"depth":FileAccess.get_sha256("res://runtime/player/grip/planar_skin_overlap_budget.gd"),
			"exact_depth_cache":FileAccess.get_sha256("res://runtime/player/grip/exact_cached_planar_skin_overlap_budget.gd")}}

func _prepare(definition: Resource, stage: Dictionary) -> Dictionary:
	var context: Dictionary = super._prepare(definition,stage)
	return SharedGripAcquisition.op_handle_prepare(self,definition,stage,context)

func _clamped(context: Dictionary, parameters: Array) -> Array:
	return SharedGripAcquisition.op_handle_clamped(self, context,parameters)

func _set_phase(phase: String, amount: float) -> void:
	SharedGripAcquisition.op_handle_set_phase(self, phase,amount)

func _guide(context: Dictionary, section: Dictionary, digit: StringName, radius: float) -> Dictionary:
	return SharedGripAcquisition.op_handle_guide(self, context,section,digit,radius)

func _measure(segments: Array, target: Dictionary, plane_id: StringName) -> Dictionary:
	return SharedGripAcquisition.op_handle_measure(self, segments,target,plane_id)

func _normal_record(record: Dictionary, circle: bool) -> Dictionary:
	return SharedGripAcquisition.op_handle_normal_record(self, record,circle)

func _circle_sample(context: Dictionary, parameters: Array, radius: float, geometry: bool = false) -> Dictionary:
	return SharedGripAcquisition.op_handle_circle_sample(self, context,parameters,radius,geometry)

func _residual(sample: Dictionary) -> PackedFloat64Array:
	return SharedGripAcquisition.op_handle_residual(self, sample)

func _safe(sample: Dictionary) -> bool:
	return SharedGripAcquisition.op_handle_safe(self, sample)

func _contact_status(sample: Dictionary) -> Dictionary:
	return SharedGripAcquisition.op_handle_contact_status(self, sample)

func _contact_requests(sample: Dictionary) -> Array:
	return SharedGripAcquisition.op_handle_contact_requests(self, sample)

func _native_proposal(context: Dictionary, handle: Dictionary, sample: Dictionary, radius: float) -> Dictionary:
	return await SharedGripAcquisition.op_handle_native_proposal(self, context,handle,sample,radius)

func _retains_observed_sections(before: Dictionary, after: Dictionary) -> bool:
	return SharedGripAcquisition.op_handle_retains_observed_sections(self, before,after)

func _preserves(sample: Dictionary) -> bool:
	return SharedGripAcquisition.op_handle_preserves(self, sample)

func _reseat_path(context: Dictionary, before: Dictionary, after: Dictionary, radius: float) -> bool:
	return SharedGripAcquisition.op_handle_reseat_path(self, context,before,after,radius)

func _respond(context: Dictionary, seed: Dictionary, radius: float, label: String, iterations: int, reseat: bool = false) -> Dictionary:
	return SharedGripAcquisition.op_handle_respond(self, context,seed,radius,label,iterations,reseat)

func _record(context: Dictionary, sample: Dictionary, label: String) -> Dictionary:
	var pose: Dictionary = _circle_sample(context,sample.parameters,sample.radius_m,true)
	if not pose.get("valid",false): return pose
	_process_frames.append({"stage":label,"phase":_guide_phase,"amount":_guide_amount,"pose":pose})
	# Retain the latest complete measured state even if a later diagnostic fails.
	var checkpoint: FileAccess = FileAccess.open("C:/WORKSPACE/test_artifacts/handle_grip_checkpoint_"+str(context.slot)+".json",FileAccess.WRITE)
	if checkpoint!=null:
		checkpoint.store_string(JSON.stringify(_json({"schema":"handle_grip_checkpoint_v1","slot":context.slot,"stage":label,"pose":pose}),"\t"))
		checkpoint.close()
	print("HANDLE_STAGE="+JSON.stringify({"slot":context.slot,"stage":label,"material_contacts":pose.material_contacts,"material_safe":pose.material_safe,"guide_safe":pose.guide_safe}))
	return pose

func _search(context: Dictionary) -> Dictionary:
	_process_frames.clear()
	var job := SharedGripAcquisition.new()
	var configured: Dictionary = job.configure_prepared(context,_config,root,_selected_digits(),_accept_runtime_trace)
	if not configured.get("valid",false): return configured
	var result: Dictionary = await job.solve()
	if not result.get("valid",false): return result
	result["initial"]=_process_frames[0].pose
	result["stages"]=_process_frames.duplicate(true)
	# Coherent candidate is for live application, not serialized report history.
	result.erase("candidate")
	return result

func _accept_runtime_trace(frame: Dictionary) -> void:
	_process_frames.append(frame)
	var pose: Dictionary = frame.pose
	var checkpoint: FileAccess = FileAccess.open("C:/WORKSPACE/test_artifacts/handle_grip_checkpoint_"+str(pose.digits[0].slot)+".json",FileAccess.WRITE)
	if checkpoint!=null:
		checkpoint.store_string(JSON.stringify(_json({"schema":"handle_grip_checkpoint_v1","slot":pose.digits[0].slot,"stage":frame.stage,"pose":pose}),"\t"))
		checkpoint.close()
	print("HANDLE_STAGE="+JSON.stringify({"slot":pose.digits[0].slot,"stage":frame.stage,"material_contacts":pose.material_contacts,"material_safe":pose.material_safe,"guide_safe":pose.guide_safe}))
