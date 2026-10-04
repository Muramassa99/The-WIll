extends SceneTree

## Read-only export of an existing actual-pose capture. No closure or pose writes.
## Launch through launch_the_will_safe.ps1. Set THE_WILL_GRIP_SLICE_REPORT to a
## workspace live_saved_wrapper_grip JSON; outputs use its _actual_slices suffix.
const Actual = preload("res://runtime/player/grip/observed_hand_pose_view.gd")
const Observer = preload("res://runtime/player/grip/prepared_grip_slice_contact.gd")
const Palm = preload("res://runtime/player/grip/prepared_palmar_slice_region.gd")
const Sections = preload("res://runtime/player/grip/prepared_saved_grip_sections.gd")
const Source = preload("res://runtime/player/grip/saved_wrapper_grip_source.gd")
const Contact = preload("res://runtime/player/grip/saved_wrapper_skin_contact.gd")
const GuideProgression = preload("res://runtime/player/grip/saved_wrapper_guide_progression.gd")
const Visibility = preload("res://runtime/player/grip/grip_target_visibility.gd")
const Preference = preload("res://runtime/player/grip/skin_section_contact_preference.gd")
const Acquisition = preload("res://runtime/player/grip/handle_grip_acquisition.gd")
const PROFILE = preload("res://core/defs/characters/josie/grip_contact_config.tres")
const ROOT := &"RL_BoneRoot"
const DIGITS: Array[StringName] = [&"middle", &"thumb", &"index", &"ring", &"pinky"]
const CONTACT_GUARD_M := Acquisition.NUMERIC_GUARD_M
const TEMPLATE := "res://tools/grip_plane_proof/live_grip_slices_view.html"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var started := Time.get_ticks_usec()
	var path := OS.get_environment("THE_WILL_GRIP_SLICE_REPORT").replace("\\", "/").simplify_path()
	if not _workspace(path) or not path.ends_with(".json"):
		_fail("Set THE_WILL_GRIP_SLICE_REPORT to a workspace JSON."); return
	var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not report is Dictionary or not report.get("actual_capture_valid", false):
		_fail("Source report has no valid actual capture."); return
	var capture_path: String = report.actual_capture_path
	var library_path: String = report.source_library
	if not _workspace(capture_path) or not _workspace(library_path):
		_fail("Capture and source library must remain in the workspace."); return
	var capture_hash := FileAccess.get_sha256(capture_path)
	var report_hash := FileAccess.get_sha256(path)
	var library_hash := FileAccess.get_sha256(library_path)
	if library_hash != report.source_library_sha256:
		_fail("Library changed since the captured live run."); return
	var file := FileAccess.open(capture_path, FileAccess.READ)
	if file == null: _fail("Capture cannot be opened."); return
	var raw: Variant = file.get_var(false)
	file.close()
	if not raw is Dictionary or not raw.get("valid", false):
		_fail("Capture is invalid."); return
	var capture: Dictionary = raw
	var live_state: Dictionary = report.get("terminal_status", {}).get(str(capture.slot), {})
	var recorded_guides: Dictionary = live_state.get("working_guides", {})
	var recorded_guidance: Dictionary = live_state.get("per_digit_guidance", {})
	var strength: Variant = null
	for assessment: Dictionary in live_state.get("final_digit_assessments", []):
		var recorded: Variant = assessment.get("preference_strength_fraction")
		if not (recorded is float or recorded is int) or (strength != null and strength != recorded):
			_fail("Recorded preference strength is missing or inconsistent."); return
		strength = recorded
	# A rejected acquisition may never emit final assessments. Preserve that
	# absence in the report rather than preventing observation of the failure.
	var observed := Actual.new().observe(PROFILE.anatomy, capture.posed_character, capture.slot, DIGITS)
	if not _valid(observed, "actual observation"): return
	var view: Dictionary = observed.view
	# store_var(false) preserves resource object IDs, not Resource contents.
	# Reload ONLY the immutable saved wrapper from the hash-matched source save.
	# Geometry transforms, skin and measurement planes remain the actual capture.
	var library: Resource = ResourceLoader.load(library_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if library == null: _fail("Source library cannot be read."); return
	var stage: Resource
	for item: Resource in library.get("saved_wips"):
		if item != null and str(item.get("forge_project_name")) == report.weapon_name:
			if stage != null: _fail("Ambiguous saved weapon name."); return
			stage = item.get("stage2_item_state")
	var frozen: Dictionary = capture.get("saved_grip_source", {})
	if stage == null or not frozen.get("source_to_weapon") is Transform3D:
		_fail("Missing saved wrapper or captured source rebase."); return
	var source := Source.from_stage2(stage, frozen.source_to_weapon)
	if not _valid(source, "saved source"): return
	if source.source_body_signature != frozen.source_body_signature or source.source_body_signature != report.input_body_signature or var_to_bytes(source.handle_packet) != var_to_bytes(frozen.handle_packet):
		_fail("Reloaded saved handle differs from the actual capture."); return
	var palm := Palm.new().prepare({"adapter":observed.adapter, "slot":capture.slot}, PROFILE.anatomy)
	if not _valid(palm, "palm identification"): return
	var planes := {}
	for digit: StringName in DIGITS:
		var state: Dictionary = view.digit_states[digit]
		planes[digit] = {"plane_to_world":state.plane_to_world, "plane_origin_id":state.plane_origin_id}
	var records: Array = view.pose_packet.origin_records.duplicate(true)
	records.append(capture.object.weapon_origin_record)
	records.append({"origin_id":source.source_origin_id, "parent_origin_id":source.source_parent_origin_id,
		"transform_to_parent":source.source_to_weapon, "owner_system":&"saved_wrapper_grip_source",
		"resolve_phase":view.pose_packet.resolve_phase, "space_type":&"weapon", "is_dynamic":false})
	var weapon: Transform3D = capture.object.weapon_to_world
	var span: Vector3 = weapon.basis * (capture.object.primary_grip_span_end_local - capture.object.primary_grip_span_start_local)
	var prepared := Sections.new().prepare(source.wrapper, source.handle_packet, weapon,
		view.pose_packet.machine_to_world, {"origin_records":records, "resolve_phase":view.pose_packet.resolve_phase,
		"digit_planes":planes, "station_axis_world":span.normalized(), "vectors_origin_id":ROOT,
		"saved_source_origin_id":source.source_origin_id}, PROFILE.contact_config)
	if not _valid(prepared, "saved surfaces"): return
	var sections := Sections.new().slice(prepared, Vector3.ZERO, ROOT, DIGITS)
	if not _valid(sections, "actual saved surface slices"): return
	var contact := Contact.new()
	var progression := GuideProgression.new()
	var visibility_query := Visibility.new()
	if not contact.begin_acquisition(&"ActualCapturedSliceExport"):
		_fail("Contact observer could not start."); return
	var output := {"schema":"actual_live_grip_slices_v1", "weapon":report.weapon_name,
		"slot":capture.slot, "source_report":path, "source_capture":capture_path,
		"source_capture_sha256":capture_hash, "observed_not_reposed":true,
		"digits":[], "material_contacts":[], "evidence":{
			"source_library":library_path, "source_library_sha256":library_hash,
			"source_report_sha256":report_hash, "source_handle_matches_capture":true,
			"saved_wrapper_reloaded_from_hash_matched_save":true,
			"geometry_reposed":false, "solver_ran":false, "production_pose_written":false,
			"wrapper_generated":false, "whole_hand_3d_contact_certified":false,
			"guide_following_verified":live_state.get("guide_following_verified", false),
			"continuous_tangency_verified":false,
			"scope":"actual skin sliced on each digit plane; saved handle and wrappers observed at captured transform",
			"live_acceptance":report.get("acceptance", {}), "articulation_valid":observed.articulation_valid,
			"bias_strength":strength, "bias_peaks_percent":Preference.PEAKS,
			"bias_spread_percentage_points":Preference.SPREAD,
			"live_assessment_numeric_guard_m":CONTACT_GUARD_M,
			"bias_parameter_provenance":"strength from live report; contour mapping, peak and spread from current rule owner"}}
	for digit: StringName in DIGITS:
		var state: Dictionary = view.digit_states[digit]
		var observer := Observer.new()
		var skin_prepared := observer.prepare(observed.adapter, digit)
		if not _valid(skin_prepared, str(digit) + " skin preparation"): return
		var skin := observer.slice_candidate(skin_prepared, view, state.plane_to_world, state.plane_origin_id)
		if not _valid(skin, str(digit) + " skin slice"): return
		skin = Palm.new().annotate(palm, view, skin, state.plane_to_world)
		if not _valid(skin, str(digit) + " palm slice"): return
		var section: Dictionary = sections.digits[digit]
		var working_section: Dictionary = section
		var working_guide: Dictionary = recorded_guides.get(str(digit), {})
		var working_sample: Dictionary = {}
		if not working_guide.is_empty():
			working_sample = progression.sample(section, float(working_guide.get("radius_m", NAN)), float(working_guide.get("progress", NAN)))
			if not _valid(working_sample, str(digit) + " recorded working guide"): return
			working_section = working_sample.section
		var target := contact.prepare(working_section)
		if not _valid(target, str(digit) + " target"): return
		# Every skin edge still bounds the working guide's no-entry area. The
		# original eligibility is restored before choosing attraction witnesses.
		var query_edges: Array = skin.segments.duplicate(true)
		for edge: Dictionary in query_edges: edge["grip_attraction_eligible"] = true
		var measured := contact.evaluate(target, query_edges, state.plane_origin_id)
		if not _valid(measured, str(digit) + " contact observation"): return
		for index: int in measured.segments.size(): measured.segments[index]["segment"] = skin.segments[index]
		var visibility := visibility_query.prepare(skin, state)
		if not _valid(visibility, str(digit) + " target visibility"): return
		for record: Dictionary in measured.segments:
			if record.segment.get("grip_attraction_eligible", true) and record.get("guide_evaluated", true):
				record["guide_visibility"] = visibility_query.evaluate(visibility, record.segment, record.witness)
		var inverse: Transform3D = state.plane_to_world.affine_inverse()
		var joints: Array = []
		for joint: Vector3 in state.joint_origins_world: joints.append(_project(inverse, joint))
		var regions := _regions(measured.segments)
		for region: Dictionary in regions:
			if region.material_contact:
				var id := "palm" if region.section == 0 else str(digit) + "/S" + str(region.section)
				if not output.material_contacts.has(id): output.material_contacts.append(id)
		output.digits.append({"digit":digit, "plane_origin_id":state.plane_origin_id,
			"plane_to_world":state.plane_to_world, "vectors_origin_id":ROOT,
			"skin_segments":skin.segments, "handle_polygon":section.handle.polygon,
			"wrapper_polygon":section.digit_target.polygon, "palm_polygon":section.palm_target.polygon,
			"working_wrapper_polygon":working_section.digit_target.polygon if not working_sample.is_empty() else PackedVector2Array(),
			"working_palm_polygon":working_section.palm_target.polygon if not working_sample.is_empty() else PackedVector2Array(),
			"working_guide":working_guide, "working_guide_geometry":working_sample.get("working_guide", {}),
			"guidance":recorded_guidance.get(str(digit), {}), "working_guide_recorded":not working_guide.is_empty(),
			"witness_policy":"nearest visible observation of captured geometry, not a replay of solver target selection",
			"center_m":section.center, "joints_m":joints, "tip_m":_project(inverse, state.tip_world),
			"wrist_m":_project(inverse, view.hand_to_world.origin), "regions":regions,
			"bias_markers":_bias_markers(skin.segments, digit),
			"material_safe":measured.material_constraint_safe, "guide_safe":measured.guide_constraint_safe,
			"angles_rad":state.angles_rad, "observed_not_reposed":true})
		output.digits[-1]["gripping_surface"] = skin.get("gripping_surface", {})
		output.digits[-1]["section_contact_preference"] = skin.get("section_contact_preference", {})
		output.digits[-1]["guide_evaluated_segment_count"] = measured.get("guide_evaluated_segment_count", skin.segments.size())
		output.digits[-1]["guide_skipped_segment_count"] = measured.get("guide_skipped_segment_count", 0)
	var expected: Array = report.get("acceptance", {}).get("distinct_actual_contact_sections", []).duplicate()
	var actual: Array = output.material_contacts.duplicate()
	expected.sort(); actual.sort()
	output.evidence["slice_contacts_match_live_report"] = expected == actual
	output.evidence["source_files_unchanged"] = capture_hash == FileAccess.get_sha256(capture_path) and library_hash == FileAccess.get_sha256(library_path) and report_hash == FileAccess.get_sha256(path)
	if not output.evidence.source_files_unchanged:
		_fail("Source files changed during observation."); return
	output.evidence["export_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	output.evidence["contact_query_statistics"] = contact.cache_statistics()
	var json := JSON.stringify(_json_safe(output), "\t")
	var template := FileAccess.get_file_as_string(TEMPLATE)
	if not template.contains("__REPORT__"):
		_fail("HTML template missing report slot."); return
	var prefix := path.get_basename() + "_actual_slices"
	var json_file := FileAccess.open(prefix + ".json", FileAccess.WRITE)
	if json_file == null: _fail("Cannot write slice JSON."); return
	json_file.store_string(json); json_file.close()
	var html_file := FileAccess.open(prefix + ".html", FileAccess.WRITE)
	if html_file == null: _fail("Cannot write slice HTML."); return
	html_file.store_string(template.replace("__REPORT__", json.replace("<", "\\u003c")))
	html_file.close()
	print(JSON.stringify({"html":prefix + ".html", "digits":output.digits.size(),
		"contacts":output.material_contacts, "contacts_match_live":expected == actual,
		"source_unchanged":output.evidence.source_files_unchanged, "export_ms":output.evidence.export_ms}))
	quit(0)

func _regions(records: Array) -> Array:
	var groups := {}
	for record: Dictionary in records:
		var edge: Dictionary = record.segment
		var section: int = int(edge.section_owner) + 1 if int(edge.section_owner) >= 0 else (0 if edge.get("palm_owned", false) else -1)
		if section < 0: continue
		if not groups.has(section):
			groups[section] = {"section":section, "gap_m":INF, "material_gap_m":INF,
				"material_depth_upper_m":0.0, "cap_m":INF, "material_safe":true,
				"strict_material_safe":true,
				"witness":{}, "material_witness":{}, "blocked_nearest_witness":{},
				"blocked_nearest_gap_m":INF, "blocked_nearest_reason":"", "blocked_guide_candidates":0}
		var region: Dictionary = groups[section]
		if record.get("guide_evaluated", true) and edge.get("grip_attraction_eligible", true):
			var visibility: Dictionary = record.get("guide_visibility", {})
			if visibility.get("accessible", false):
				if record.guide_gap_m < region.gap_m:
					region.gap_m = record.guide_gap_m; region.witness = record.witness
			else:
				region.blocked_guide_candidates += 1
				if record.guide_gap_m < region.blocked_nearest_gap_m:
					region.blocked_nearest_gap_m = record.guide_gap_m
					region.blocked_nearest_witness = record.witness
					region.blocked_nearest_reason = visibility.get("reason", "visibility_unverified")
		if edge.get("grip_attraction_eligible", true) and record.material_gap_m < region.material_gap_m:
			region.material_gap_m = record.material_gap_m; region.material_witness = record.material_witness
		region.material_depth_upper_m = maxf(region.material_depth_upper_m, record.depth_upper_m)
		region.cap_m = minf(region.cap_m, float(edge.max_inward_depth_m) if not edge.get("allowance_unassigned", true) else 0.0)
		region.strict_material_safe = region.strict_material_safe and record.material_constraint_safe
		# Match the existing actual-pose assessor's numerical guard. Preserve
		# the stricter kernel result separately; no runtime cap is changed here.
		region.material_safe = region.material_safe and record.depth_upper_m <= record.max_inward_depth_m + CONTACT_GUARD_M
	var out: Array = []
	for section: int in [1,2,3,0]:
		if groups.has(section):
			var region: Dictionary = groups[section]
			region["material_contact"] = region.material_safe and region.material_gap_m <= CONTACT_GUARD_M
			out.append(region)
	return out

func _bias_markers(edges: Array, digit: StringName) -> Array:
	var markers: Array = []
	if digit == &"thumb": return markers
	for edge: Dictionary in edges:
		if not edge.get("grip_attraction_eligible", true): continue
		var owner := int(edge.get("section_owner", -1))
		var bias: Dictionary = edge.get("location_bias", {})
		if owner < 0 or owner > 2 or bias.is_empty(): continue
		var peak: float = Preference.PEAKS[owner]
		var a: float = bias.a_percent
		var b: float = bias.b_percent
		if absf(b - a) < 0.000001 or peak < minf(a,b) or peak > maxf(a,b): continue
		markers.append({"section":owner + 1, "percent":peak,
			"point_m":(edge.a as Vector2).lerp(edge.b, (peak-a)/(b-a)),
			"soft_preference_only_not_contact":true})
	return markers

func _project(inverse: Transform3D, point: Vector3) -> Vector2:
	var local := inverse * point
	return Vector2(local.x, local.y)

func _json_safe(value: Variant) -> Variant:
	if value is Vector2: return [value.x, value.y]
	if value is Vector3: return [value.x, value.y, value.z]
	if value is Transform3D: return {"origin":_json_safe(value.origin), "basis":[_json_safe(value.basis.x),_json_safe(value.basis.y),_json_safe(value.basis.z)]}
	if value is Dictionary:
		var out := {}
		for key: Variant in value: out[str(key)] = _json_safe(value[key])
		return out
	if value is Array or value is PackedVector2Array or value is PackedVector3Array or value is PackedInt32Array or value is PackedFloat32Array or value is PackedFloat64Array or value is PackedStringArray:
		var out: Array = []
		for item: Variant in value: out.append(_json_safe(item))
		return out
	if value is float and not is_finite(value): return null
	return value

func _workspace(path: String) -> bool:
	return path.replace("\\", "/").simplify_path().to_lower().begins_with("c:/workspace/")

func _valid(value: Dictionary, label: String) -> bool:
	if value.get("valid", false): return true
	_fail(label + ": " + JSON.stringify(_json_safe(value)))
	return false

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
