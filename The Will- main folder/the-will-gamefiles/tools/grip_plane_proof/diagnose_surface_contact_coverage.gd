extends SceneTree
const Anatomy = preload("res://runtime/player/grip/prepared_surface_grip_anatomy.gd")
const Actual = preload("res://runtime/player/grip/observed_hand_pose_view.gd")
const Source = preload("res://runtime/player/grip/saved_wrapper_grip_source.gd")
const Surface = preload("res://runtime/player/grip/grip_surface_query.gd")
const Solver = preload("res://runtime/player/grip/surface_driven_grip_solver.gd")
const SkinContact = preload("res://runtime/player/grip/surface_grip_skin_contact.gd")
const PROFILE = preload("res://core/defs/characters/josie/grip_contact_config.tres")
const DIGITS: Array[StringName] = [&"middle", &"index", &"ring", &"pinky", &"thumb"]
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var path := OS.get_environment("THE_WILL_GRIP_SURFACE_REPORT").replace("\\", "/").simplify_path()
	if not path.to_lower().begins_with("c:/workspace/"): _fail("workspace report required"); return
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	if FileAccess.get_sha256(report.actual_capture_path) != report.actual_capture_sha256 or FileAccess.get_sha256(report.source_library) != report.source_library_sha256:
		_fail("source hash mismatch"); return
	var file := FileAccess.open(report.actual_capture_path, FileAccess.READ)
	var capture: Dictionary = file.get_var(false)
	file.close()
	var anatomy := Anatomy.new()
	var prepared := anatomy.prepare(PROFILE.anatomy, capture, PROFILE.contact_config)
	if not prepared.get("valid", false): _fail(str(prepared)); return
	var observed := Actual.new().observe(PROFILE.anatomy, capture.posed_character, capture.slot, DIGITS)
	if not observed.get("valid", false): _fail(str(observed)); return
	var library: Resource = load(report.source_library)
	var stage: Resource
	for wip: Resource in library.saved_wips:
		if str(wip.forge_project_name) == report.weapon_name: stage = wip.stage2_item_state
	var source := Source.from_stage2(stage, capture.saved_grip_source.source_to_weapon)
	var surface := Surface.prepare(source, PROFILE.contact_config)
	if not surface.get("valid", false): _fail(str(surface)); return
	var solver := Solver.new()
	solver.set("_prepared", prepared)
	solver.set("_surface", surface)
	solver.set("_source_to_weapon", surface.source_to_weapon)
	solver.set("_weapon", capture.object.weapon_to_world)
	solver.set("_pivot_local", capture.object.grip_pivot_local)
	var axis: Vector3 = capture.object.weapon_to_world.basis * (capture.object.primary_grip_span_end_local - capture.object.primary_grip_span_start_local)
	solver.set("_axis", axis.normalized())
	var reach: float = maxf(surface.source_bounds.size.length(), 0.01)
	for digit: StringName in prepared.adapter.digit_inputs:
		var length := 0.0
		for value: float in prepared.adapter.digit_inputs[digit].digit.section_lengths_m: length += value
		reach = maxf(reach, length * 2.0)
	solver.set("_reach", reach)
	solver.set("_metrics", {"native_surface_queries":0, "sparse_skin_evaluations":0})
	var states: Dictionary = observed.view.digit_states
	var frames: Dictionary = solver._frames(states)
	var sparse: Dictionary = solver._contacts(states)
	var all := {}
	var blockers: Array = []
	var key_witnesses: Array = []
	for sample: Dictionary in anatomy.pose_samples(prepared, prepared.safety_samples, frames):
		if not sample.get("grip_attraction_eligible", false) or sample.digit not in Solver.ACTIVE or int(sample.section) <= 0: continue
		var hit: Dictionary = solver._skin_material(sample)
		var key := str(sample.digit) + ":S" + str(sample.section)
		var triangle := int(sample.triangle_id)
		var patches: Dictionary = prepared.digits[sample.digit].sections[int(sample.section)-1].contact_patches
		var inside := patches.has(triangle) and SkinContact._inside(sample.barycentric, patches[triangle].polygon_barycentric)
		var in_sparse := false
		for chosen: Dictionary in prepared.digits[sample.digit].sections[int(sample.section)-1].samples:
			if chosen.triangle_id == triangle and (chosen.barycentric as Vector3).is_equal_approx(sample.barycentric): in_sparse = true
		var row := {"section":key, "source_id":sample.source_id, "triangle_id":triangle, "barycentric":str(sample.barycentric),
			"cap_m":sample.cap_m, "percent":sample.percent, "physical":hit,
			"triangle_has_contact_patch":patches.has(triangle), "inside_contact_patch":inside, "in_sparse_targets":in_sparse}
		if str(sample.source_id) == "0/4047" or (hit.get("hit", false) and float(hit.gap_m) < -float(sample.cap_m)-Solver.NUMERIC_GUARD_M):
			var point: Vector3 = sample.point_world
			var normal: Vector3 = sample.normal_world
			row["actual_point_world"] = point
			row["anatomical_normal_world"] = normal
			row["actual_point_outward_ray"] = solver._trace(&"physical", point, point + normal * reach)
			row["actual_point_inward_ray"] = solver._trace(&"physical", point, point - normal * reach)
			row["buried_origin_world"] = point - normal * (float(sample.cap_m) + Solver.CONTACT_BAND_M * 2.0)
		if str(sample.source_id) == "0/4047": key_witnesses.append(row)
		if not hit.get("hit", false): continue
		if float(hit.gap_m) < -float(sample.cap_m)-Solver.NUMERIC_GUARD_M:
			blockers.append(row); continue
		if float(hit.gap_m) > Solver.CONTACT_BAND_M: continue
		if not all.has(key): all[key] = {"physical_legal_count":0, "continuous_valid_count":0, "witnesses":[]}
		all[key].physical_legal_count += 1
		if not hit.has("point_world"): continue
		var anchor: Dictionary = solver._make_anchor(sample.digit, int(sample.section)-1, hit, sample)
		var mobile: Dictionary = solver._anchor_sample(anchor, states, frames)
		row["mobile_valid"] = mobile.get("valid", false)
		row["anchor_valid"] = solver._anchor_contact_valid(anchor, mobile, states)
		row["mobile_reason"] = mobile.get("reason", "")
		if row.anchor_valid: all[key].continuous_valid_count += 1
		if all[key].witnesses.size() < 6: all[key].witnesses.append(row)
	var output := {"scope":"Read-only existing actual pose; full eligible safety carrier comparison, no new solve or geometry edits",
		"source_report":path, "source_sha256":FileAccess.get_sha256(path), "sparse_sections":sparse.sections,
		"full_pool_contacts":all, "full_pool_overcap_samples":blockers, "pinky_4047":key_witnesses,
		"totals":solver.get("_metrics")}
	var out_path := path.get_basename() + "_contact_coverage_ray_origin.json"
	if FileAccess.file_exists(out_path): _fail("refuse overwrite"); return
	file = FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"\t")); file.close()
	print(JSON.stringify({"report":out_path,"sparse":sparse.sections,"full_contact_sections":all.keys(),"overcap_count":blockers.size(),"pinky4047_count":key_witnesses.size()}))
	quit(0)
func _fail(reason: String) -> void:
	push_error(reason); quit(1)
