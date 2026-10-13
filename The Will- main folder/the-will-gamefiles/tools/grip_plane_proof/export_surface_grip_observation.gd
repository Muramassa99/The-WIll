extends SceneTree

## Geometry-only V6 report from an actually captured natural UI result. Slicing
## is an offline observation here, never a reintroduced runtime grip solver.
## Set THE_WILL_GRIP_SURFACE_REPORT to trace_skill_crafter_grip's _status.json.
const Actual = preload("res://runtime/player/grip/observed_hand_pose_view.gd")
const SkinSlice = preload("res://runtime/player/grip/prepared_grip_slice_contact.gd")
const Palm = preload("res://runtime/player/grip/prepared_palmar_slice_region.gd")
const PlaneSection = preload("res://runtime/player/grip/prepared_weapon_plane_section.gd")
const Source = preload("res://runtime/player/grip/saved_wrapper_grip_source.gd")
const PROFILE = preload("res://core/defs/characters/josie/grip_contact_config.tres")
const TEMPLATE := "res://tools/grip_plane_proof/surface_grip_observation_view.html"
const ROOT := &"RL_BoneRoot"
const DIGITS: Array[StringName] = [&"middle", &"index", &"ring", &"pinky", &"thumb"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var started := Time.get_ticks_usec()
	var report_path := OS.get_environment("THE_WILL_GRIP_SURFACE_REPORT").replace("\\", "/").simplify_path()
	if not _workspace(report_path) or not report_path.ends_with(".json"):
		_fail("Set THE_WILL_GRIP_SURFACE_REPORT to a workspace trace status JSON."); return
	var raw_report: Variant = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	if not raw_report is Dictionary or not raw_report.has("actual_capture_path") or not raw_report.has("actual_capture_sha256"):
		_fail("An actual pose capture is required; enable THE_WILL_GRIP_TRACE_CAPTURE_POSE=1."); return
	var report: Dictionary = raw_report
	var capture_path: String = report.actual_capture_path
	var library_path: String = report.source_library
	if not _workspace(capture_path) or not _workspace(library_path):
		_fail("Capture and library must remain inside the workspace."); return
	var capture_hash := FileAccess.get_sha256(capture_path)
	var library_hash := FileAccess.get_sha256(library_path)
	var report_hash := FileAccess.get_sha256(report_path)
	if library_hash != report.source_library_sha256 or capture_hash != report.actual_capture_sha256:
		_fail("Source files changed after the actual observation."); return
	var file := FileAccess.open(capture_path, FileAccess.READ)
	if file == null: _fail("Cannot read actual pose capture."); return
	var raw_capture: Variant = file.get_var(false)
	file.close()
	if not raw_capture is Dictionary or not raw_capture.get("valid", false):
		_fail("Invalid captured pose."); return
	var capture: Dictionary = raw_capture
	var observed := Actual.new().observe(PROFILE.anatomy, capture.posed_character, capture.slot, DIGITS)
	if not observed.get("valid", false): _fail("Actual observation failed: " + str(observed)); return
	var view: Dictionary = observed.view
	var library: Resource = ResourceLoader.load(library_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if library == null: _fail("Cannot load saved source library."); return
	var stage: Resource
	for item: Resource in library.get("saved_wips"):
		if item != null and str(item.get("forge_project_name")) == report.weapon_name:
			if stage != null: _fail("Ambiguous saved weapon name."); return
			stage = item.get("stage2_item_state")
	var frozen: Dictionary = capture.get("saved_grip_source", {})
	if stage == null or not frozen.get("source_to_weapon") is Transform3D:
		_fail("Missing saved source or captured source rebase."); return
	var source := Source.from_stage2(stage, frozen.source_to_weapon)
	if not source.get("valid", false): _fail("Saved source unavailable: " + str(source)); return
	if source.source_body_signature != report.input_body_signature or var_to_bytes(source.handle_packet) != var_to_bytes(frozen.handle_packet):
		_fail("Saved physical handle differs from the captured handle."); return
	var palm := Palm.new().prepare({"adapter":observed.adapter, "slot":capture.slot}, PROFILE.anatomy)
	if not palm.get("valid", false): _fail("Palm observation failed: " + str(palm)); return
	var wrapper: Resource = source.wrapper
	var arrays := {
		"physical":[source.handle_packet.vertices, source.handle_packet.indices],
		"digit":[wrapper.get("target_vertices_m"), wrapper.get("target_indices")],
		"palm":[wrapper.get("palm_target_vertices_m"), wrapper.get("palm_target_indices")],
	}
	var s1: Variant = wrapper.get("non_thumb_s1_target_vertices_m")
	if s1 is PackedVector3Array and not s1.is_empty():
		arrays["s1"] = [s1, wrapper.get("non_thumb_s1_target_indices")]
	var source_to_world: Transform3D = capture.object.weapon_to_world * source.source_to_weapon
	var surfaces := {}
	for kind: String in arrays:
		var points: PackedVector3Array = arrays[kind][0]
		var indices: PackedInt32Array = arrays[kind][1]
		var triangles := PackedVector3Array()
		for index: int in indices: triangles.append(source_to_world * points[index])
		surfaces[kind] = {"valid":true, "triangles_world":triangles,
			"surface_source_origin_id":source.source_origin_id, "resolved_world_origin_id":ROOT}
	var state: Dictionary = report.get("owner_status", {}).get(str(capture.slot), {})
	var totals: Dictionary = state.get("solver_totals", {})
	var assessment: Dictionary = totals.get("section_assessment", state.get("section_assessment",{}))
	var thumb_enabled: bool = state.get("thumb_solve_enabled",false) or int(assessment.get("required_count",12)) > 12
	var output := {"schema":"surface_grip_actual_observation_v1", "weapon":report.weapon_name,
		"slot":capture.slot, "digits":[], "solver_ms":state.get("solver_total_ms", 0.0),
		"material_contacts":state.get("material_contacts", []), "section_assessment":assessment,
		"sampled_material_safe":state.get("sampled_material_safe", false), "target_contract":totals.get("target_contract", {}),
		"reseat_attempts":totals.get("reseat_attempts", 0), "reseat_history":totals.get("reseat_history", []),
		"thumb_deferred":not thumb_enabled, "grip_success_asserted":false, "saved_surface_depths_mm":{
			"digit":float(wrapper.get("guide_inward_target_offset_m")) * 1000.0,
			"palm":float(wrapper.get("palm_guide_target_depth_m")) * 1000.0},
		"evidence":{"source_capture":capture_path, "source_report":report_path, "source_library":library_path,
			"source_capture_sha256":capture_hash, "source_report_sha256":report_hash, "source_library_sha256":library_hash,
			"geometry_reposed":false, "solver_ran":false, "wrapper_regenerated":false,
			"reported_capture_valid":report.get("actual_capture_valid", false), "capture_binary_valid":true,
			"source_status_capture_flag_disagrees":not report.get("actual_capture_valid", false),
			"actual_articulation_valid":observed.get("articulation_valid", false),
			"scope":"Actual captured skin and saved geometry only; no inferred contact points or full-surface certification."}}
	output["contact_evidence"] = _contact_evidence(totals, assessment, state.get("material_contacts", []))
	# Frozen replay keeps the exact solver packet beside the captured pose. Read
	# recorded metrics only; this does not evaluate or re-pose the observed skin.
	var recorded_path := report_path.trim_suffix("_status.json") + "_result.bin"
	if FileAccess.file_exists(recorded_path):
		var recorded_file := FileAccess.open(recorded_path, FileAccess.READ)
		if recorded_file != null:
			var recorded: Variant = recorded_file.get_var(false)
			recorded_file.close()
			if recorded is Dictionary and recorded.get("valid", false):
				var recorded_totals: Dictionary = recorded.get("totals", {})
				output["contact_evidence"] = _contact_evidence(recorded_totals, assessment, state.get("material_contacts", []))
				output["recorded_solver"] = {"palm_seating":recorded.get("palm_seating",{}),
					"sections":recorded.get("totals",{}).get("final_sections",[]),
					"thumb_fit":recorded.get("totals",{}).get("thumb_fit",{}),
					"material_validation":recorded.get("material_validation",{}),
					"attraction_witnesses":recorded_totals.get("coupled_hand_fit",{}).get("attraction_witnesses",[]),
					"source_result":recorded_path,"source_result_sha256":FileAccess.get_sha256(recorded_path)}
	for digit: StringName in DIGITS:
		var digit_state: Dictionary = view.digit_states[digit]
		var row := {"digit":digit, "plane_origin_id":digit_state.plane_origin_id,
			"angles_rad":digit_state.angles_rad, "skin_segments":[], "polygons":{}, "errors":[]}
		var skin_observer := SkinSlice.new()
		var prepared := skin_observer.prepare(observed.adapter, digit)
		if prepared.get("valid", false):
			var skin := skin_observer.slice_candidate(prepared, view, digit_state.plane_to_world, digit_state.plane_origin_id)
			if skin.get("valid", false): skin = Palm.new().annotate(palm, view, skin, digit_state.plane_to_world)
			if skin.get("valid", false): row.skin_segments = skin.segments
			else: row.errors.append({"surface":"skin", "reason":skin.get("reason", "observation_failed")})
		else: row.errors.append({"surface":"skin", "reason":prepared.get("reason", "prepare_failed")})
		for kind: String in surfaces:
			if kind == "s1" and digit == &"thumb": continue
			var slicer := PlaneSection.new()
			var prepared_surface := slicer.prepare(surfaces[kind], digit_state.plane_to_world, digit_state.plane_origin_id)
			var section := slicer.slice(prepared_surface, digit_state.plane_to_world) if prepared_surface.get("valid", false) else prepared_surface
			if section.get("valid", false): row.polygons[kind] = section.polygon
			else: row.errors.append({"surface":kind, "reason":section.get("reason", "section_failed")})
		var inverse: Transform3D = digit_state.plane_to_world.affine_inverse()
		var joints: Array = []
		for joint: Vector3 in digit_state.joint_origins_world: joints.append(_project(inverse, joint))
		row["joints_m"] = joints
		row["tip_m"] = _project(inverse, digit_state.tip_world)
		row["wrist_m"] = _project(inverse, view.hand_to_world.origin)
		output.digits.append(row)
	output.evidence["source_files_unchanged"] = capture_hash == FileAccess.get_sha256(capture_path) and library_hash == FileAccess.get_sha256(library_path) and report_hash == FileAccess.get_sha256(report_path)
	output.evidence["observation_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	if not output.evidence.source_files_unchanged: _fail("Source files changed during export."); return
	var prefix := report_path.get_basename() + "_observation"
	if FileAccess.file_exists(prefix + ".json") or FileAccess.file_exists(prefix + ".html"):
		_fail("Refusing to overwrite an existing observation."); return
	var json := JSON.stringify(_json_safe(output), "\t")
	var template := FileAccess.get_file_as_string(TEMPLATE)
	if not template.contains("__REPORT__"): _fail("Missing HTML report placeholder."); return
	var json_file := FileAccess.open(prefix + ".json", FileAccess.WRITE)
	if json_file == null: _fail("Cannot write observation JSON."); return
	json_file.store_string(json); json_file.close()
	var html_file := FileAccess.open(prefix + ".html", FileAccess.WRITE)
	if html_file == null: _fail("Cannot write observation HTML."); return
	html_file.store_string(template.replace("__REPORT__", json.replace("<", "\\u003c"))); html_file.close()
	print("SURFACE_GRIP_OBSERVATION " + prefix + ".html")
	quit(0)

func _contact_evidence(totals: Dictionary, assessment: Dictionary, material_contacts: Array) -> Dictionary:
	var maximum: Array = []
	for section: Variant in totals.get("maximum_depth_sections", material_contacts):
		if String(section) != "palm": maximum.append(section)
	return {"physical_contact_reported":totals.has("physically_engaged_sections"),
		"physical_sections":totals.get("physically_engaged_sections", []),
		"maximum_depth_sections":maximum,
		"palm_physical_contact":totals.get("palm_engaged", null),
		"palm_maximum_depth":assessment.get("palm_contact", totals.get("palm_contact", null)),
		"depth_witnesses":totals.get("final_sections", []),
		"attraction_witnesses":totals.get("coupled_hand_fit", {}).get("attraction_witnesses", []),
		"physical_contact_definition":"Facing-eligible sampled skin within the 0.05 mm contact band and its own overlap allowance.",
		"maximum_depth_definition":"A measured sample reaches the existing maximum-overlap depth band; touching alone does not qualify.",
		"witness_definition":"Depth witnesses are selected for acceptance evidence; their skin percentages need not match the optimizer's biased attraction witnesses.",
		"acceptance_contract_changed":false}

func _project(inverse: Transform3D, point: Vector3) -> Vector2:
	var local := inverse * point
	return Vector2(local.x, local.y)

func _workspace(path: String) -> bool:
	return path.replace("\\", "/").simplify_path().to_lower().begins_with("c:/workspace/")

func _json_safe(value: Variant) -> Variant:
	if value is Vector2: return [value.x, value.y]
	if value is Vector3: return [value.x, value.y, value.z]
	if value is Transform3D: return {"origin":_json_safe(value.origin), "basis":[_json_safe(value.basis.x), _json_safe(value.basis.y), _json_safe(value.basis.z)]}
	if value is Dictionary:
		var out := {}
		for key: Variant in value: out[str(key)] = _json_safe(value[key])
		return out
	if value is Array or value is PackedVector2Array or value is PackedVector3Array or value is PackedInt32Array or value is PackedFloat32Array or value is PackedFloat64Array or value is PackedStringArray:
		var out: Array = []
		for item: Variant in value: out.append(_json_safe(item))
		return out
	return value

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
