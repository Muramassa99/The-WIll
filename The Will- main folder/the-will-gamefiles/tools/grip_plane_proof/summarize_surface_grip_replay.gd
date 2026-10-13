extends SceneTree

## Read recorded packets only. No anatomy preparation, solver or pose changes.
func _init() -> void:
	var directory:=OS.get_environment("THE_WILL_GRIP_REPLAY_DIR").replace("\\","/").simplify_path()
	if not directory.to_lower().begins_with("c:/workspace/"):
		push_error("Replay directory must be in workspace"); quit(1); return
	var summary: Variant=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("summary.json")))
	if not summary is Dictionary: push_error("Missing replay summary"); quit(1); return
	var rows: Array=[]
	for item: Dictionary in summary.cases:
		var file:=FileAccess.open(item.result_path,FileAccess.READ)
		if file==null: push_error("Missing recorded result"); quit(1); return
		var result: Dictionary=file.get_var(false); file.close()
		var totals: Dictionary=result.get("totals",{})
		rows.append({"weapon_name":item.weapon_name,"solver_ms":item.solver_ms,"valid":result.get("valid",false),
			"reason":result.get("reason",""),"detail":result.get("detail",{}),"palm_seating":result.get("palm_seating",{}),
			"sections":result.get("totals",{}).get("final_sections",[]),"thumb_fit":result.get("totals",{}).get("thumb_fit",{}),
			"material_validation":result.get("material_validation",{}),"section_assessment":totals.get("section_assessment",result.get("section_assessment",{})),
			"physical_contact_reported":totals.has("physically_engaged_sections"),
			"physically_engaged_sections":totals.get("physically_engaged_sections",[]),
			"maximum_depth_sections":totals.get("maximum_depth_sections",[]),
			"palm_physically_engaged":totals.get("palm_engaged",null),
			"palm_maximum_depth":totals.get("section_assessment",result.get("section_assessment",{})).get("palm_contact",null),
			"attraction_witnesses":totals.get("coupled_hand_fit",{}).get("attraction_witnesses",[]),
			"actual_capture_valid":item.get("actual_capture_valid",false),"source_result":item.result_path,
			"source_result_sha256":FileAccess.get_sha256(item.result_path)})
	var path:=directory.path_join("recorded_assessment.json")
	if FileAccess.file_exists(path) and OS.get_environment("THE_WILL_GRIP_REPLAY_REFRESH_SUMMARY") != "1":
		push_error("Refusing to overwrite recorded assessment without explicit refresh"); quit(1); return
	var output:=FileAccess.open(path,FileAccess.WRITE)
	if output==null: push_error("Cannot write recorded assessment"); quit(1); return
	output.store_string(JSON.stringify({"schema":"recorded_surface_grip_assessment_v1","cases":rows,"solver_reran":false,
		"acceptance_contract_changed":false,"depth_witnesses_are_not_attraction_witnesses":true,
		"physical_contact_is_distinct_from_maximum_depth_qualification":true},"\t")); output.close()
	print("RECORDED_SURFACE_GRIP_ASSESSMENT ",path)
	quit(0)
