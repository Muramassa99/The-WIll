extends "res://tools/grip_plane_proof/run_handle_grip_process_proof.gd"

## Full selected-hand controller, retaining the same circle/material/reseat rules.
## Historical complete skin poses are reused only through explicit extension proof.
const Extension = preload("res://tools/grip_plane_proof/extend_prepared_anatomy_capture.gd")
const TemplateFixture = preload("res://tools/grip_plane_proof/linear_handle_template_fixture.gd")
var _full_anatomy: Dictionary = {}
var _extension_evidence: Array = []
var _fixture: Dictionary = {}
var _fixture_builder := TemplateFixture.new()


func _selected_digits() -> Array[StringName]:
	return [&"middle", &"thumb", &"index", &"ring", &"pinky"]


func _anatomy_source() -> Dictionary:
	return _full_anatomy


func _run() -> void:
	var path: String = OS.get_environment("THE_WILL_ANATOMY_RESOURCE_PATH")
	if not path.begins_with("res://tools/grip_plane_proof/prepared_characters/josie/") or path.get_extension() != "tres":
		push_error("Explicit full-hand prepared character resource required"); quit(1); return
	_full_anatomy = {"path":path,"signature":path.get_file().get_basename(),"revision":"rest_all_digits_surface_measurements_v1"}
	var store := Store.new()
	var old: Dictionary = store.load_matching(OldInputs.DEFINITION_PATH,OldInputs.SIGNATURE,"rest_middle_thumb_surface_measurements_v1")
	var current: Dictionary = store.load_matching(path,_full_anatomy.signature,_full_anatomy.revision)
	if not old.get("valid",false) or not current.get("valid",false):
		push_error(str({"old":old.get("status"),"new":current.get("status")})); quit(1); return
	var profile: String = OS.get_environment("THE_WILL_GRIP_TEMPLATE_ID")
	if not profile.is_empty():
		_fixture = _fixture_builder.load_profile(profile)
		if not _fixture.get("valid",false): push_error(str(_fixture)); quit(1); return
	var inputs: PackedStringArray = OS.get_environment("THE_WILL_GRIP_PLACEMENT_PATHS").split(";",false)
	if inputs.is_empty(): push_error("Explicit historical placement inputs required"); quit(1); return
	var adapted_paths: PackedStringArray = []
	var stamp: String = Time.get_datetime_string_from_system().replace(":","-")
	for requested: String in inputs:
		var source: String = requested.replace("\\","/").simplify_path()
		if not _workspace_trace_path(source): push_error("Invalid workspace trace path"); quit(1); return
		var file: FileAccess = FileAccess.open(source,FileAccess.READ)
		if file == null: push_error("Missing trace"); quit(1); return
		var trace: Variant = file.get_var(false); file.close()
		if not trace is Dictionary: push_error("Invalid trace"); quit(1); return
		var adapted: Dictionary = Extension.new().extend_trace(old.resource,current.resource,trace)
		if not adapted.get("valid",false): push_error(str(adapted)); quit(1); return
		# Prove the new digit inputs have all captured contributors and parents.
		for transaction: Dictionary in adapted.trace.transactions:
			for stage: Dictionary in transaction.get("finger_inputs",[]):
				var prepared: Dictionary = Candidate.new().prepare(current.resource,stage.posed_character,stage.slot,_selected_digits())
				if not prepared.get("valid",false): push_error(str(prepared)); quit(1); return
		var output: String = "C:/WORKSPACE/test_artifacts/full_hand_placement_"+str(trace.slot)+"_"+stamp+".bin"
		if FileAccess.file_exists(output): push_error("Refusing to replace prior adapted trace"); quit(1); return
		file = FileAccess.open(output,FileAccess.WRITE)
		if file == null: push_error("Cannot save adapted trace"); quit(1); return
		file.store_var(adapted.trace,false); file.close()
		_extension_evidence.append({"original_trace":source,"original_trace_sha256":FileAccess.get_sha256(source),
			"adapted_trace":output,"adapted_trace_sha256":FileAccess.get_sha256(output),"verification":adapted.verification})
		adapted_paths.append(output)
	OS.set_environment("THE_WILL_GRIP_PLACEMENT_PATHS",";".join(adapted_paths))
	await super._run()


func _report_stem() -> String:
	return "full_hand_grip_input" if OS.get_environment("THE_WILL_FULL_HAND_INPUT_ONLY") == "1" else "full_hand_grip_process"


func _report_extensions() -> Dictionary:
	var out: Dictionary = super._report_extensions()
	out["scope"] = "isolated_all_five_digits_and_conservative_palmar_core"
	out["selected_digits"] = _selected_digits()
	out["anatomy_extension_evidence"] = _extension_evidence.duplicate(true)
	out["full_hand_runner_sha256"] = FileAccess.get_sha256(get_script().resource_path)
	out["capture_extension_sha256"] = FileAccess.get_sha256("res://tools/grip_plane_proof/extend_prepared_anatomy_capture.gd")
	out.source_sha256.runner = FileAccess.get_sha256("res://tools/grip_plane_proof/run_handle_grip_process_proof.gd")
	if not _fixture.is_empty(): out["template_fixture"] = _fixture.metadata.duplicate(true)
	return out


func _prepare(definition: Resource, stage: Dictionary) -> Dictionary:
	var input: Dictionary = stage
	var built: Dictionary = {}
	if not _fixture.is_empty():
		built = _fixture_builder.build_for_stage(_fixture,stage)
		if not built.get("valid",false): return built
		input = built.stage
	var context: Dictionary = super._prepare(definition,input)
	if context.get("valid",false) and not built.is_empty(): context["template_fixture"] = built.metadata
	return context


func _search(context: Dictionary) -> Dictionary:
	if OS.get_environment("THE_WILL_FULL_HAND_INPUT_ONLY") == "1":
		_circle_cache.clear(); _slice_cache.clear(); _circle_evaluations = 0; _set_phase("circle",0.0)
		var sample: Dictionary = _circle_sample(context,context.open_parameters,0.05,true)
		return {"valid":sample.get("valid",false),"reason":sample.get("reason",""),"slot":context.slot,
			"selected":sample,"selected_digits":_selected_digits(),"production_pose_written":false,"grip_accepted":false}
	var result: Dictionary = await super._search(context)
	if context.has("template_fixture"): result["template_fixture"] = context.template_fixture
	return result
