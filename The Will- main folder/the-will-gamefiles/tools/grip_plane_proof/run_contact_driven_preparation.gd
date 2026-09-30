extends SceneTree

## W3 circle preparation and W4 saved-wrapper attempt. Frozen workspace inputs;
## never opens gameplay or player saves. Structural PASS is not a grip verdict.
## Saved Forge triangles remain unscaled. Fixture placement reuses the captured
## handle direction, then centers the saved span at the captured Middle plane.
## This is fixture setup, not axial motion by the seating solver.
const Acquisition = preload("res://runtime/player/grip/handle_grip_acquisition.gd")
const Candidate = preload("res://runtime/player/grip/prepared_hand_candidate_pose.gd")
const Sections = preload("res://runtime/player/grip/prepared_saved_grip_sections.gd")
const Follow = preload("res://runtime/player/grip/contact_driven_grip_preparation.gd")
const Palm = preload("res://runtime/player/grip/prepared_palmar_slice_region.gd")
const Packet = preload("res://core/resolvers/primary_grip_handle_mesh_packet.gd")
const Config = preload("res://core/defs/characters/josie/grip_contact_config.tres")
const Chronology = preload("res://runtime/player/grip/grip_chronology.gd")
const ROOT := &"RL_BoneRoot"
const LIBRARY := "C:/WORKSPACE/test_artifacts/forge_v2_grip_target_wrapper_2026-09-28T03-59-21_straight_library.tres"
const LIBRARY_HASH := "8d6920bbf783e983499aee5c42ae59b23867475dcfacc243d691f626bae7dfa6"
const TRACES := {
	"C:/WORKSPACE/test_artifacts/full_hand_placement_hand_right_2026-09-27T14-46-36.bin": "3e161def3a097dcd5942534b82e9bcc883bd969f6591e92d112611921d77075f",
	"C:/WORKSPACE/test_artifacts/full_hand_placement_hand_left_2026-09-27T14-46-36.bin": "2f55e79b3bd132272447a84c683703f52f4f774aa4f8239ee3d83ac917732c4f",
}
var _failures: Array[String] = []
var _cases: Array = []
var _checks := 0
var _prefix: String
var _started: int
var _trace_run_span := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_started = Time.get_ticks_usec()
	Chronology.event("preparation.runner.start", {"scope":"accepted_frozen_fixture", "ui_actions_measured":false,
		"natural_completion":true,"hand_count":TRACES.size(),"source_library":LIBRARY,"source_library_sha256":LIBRARY_HASH})
	_trace_run_span = Chronology.begin("preparation.runner.full_cycle", {"scope":"accepted_frozen_fixture"})
	_prefix = "C:/WORKSPACE/test_artifacts/contact_driven_preparation_" + Time.get_datetime_string_from_system().replace(":", "-")
	var span := Chronology.begin("preparation.runner.verify_library", {})
	var library_matches := _check(FileAccess.get_sha256(LIBRARY) == LIBRARY_HASH, "saved wrapper fixture hash")
	Chronology.finish(span, {"valid":library_matches})
	if not library_matches:
		_finish(); return
	span = Chronology.begin("preparation.runner.load_library", {})
	var library: Resource = ResourceLoader.load(LIBRARY, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	Chronology.finish(span, {"loaded":library != null})
	if not _check(library != null and library.saved_wips.size() == 1, "one frozen saved Forge weapon"):
		_finish(); return
	var wip: Resource = library.saved_wips[0]
	var stage2: Resource = wip.stage2_item_state
	if not _check(stage2.primary_grip_handle_mesh_source == Packet.SOURCE and stage2.primary_grip_handle_mesh_origin_id == Packet.VERTICES_ORIGIN_ID,
		"saved physical handle provenance"):
		_finish(); return
	span = Chronology.begin("preparation.runner.build_physical_packet", {})
	var arrays: Array = stage2.primary_grip_handle_mesh_state.surface_arrays
	var vertices := PackedVector3Array()
	for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		vertices.append(vertex * stage2.cell_world_size_meters)
	var packet: Dictionary = Packet.build(vertices, arrays[Mesh.ARRAY_INDEX], stage2.primary_grip_handle_body_signature)
	Chronology.finish(span, {"work_counts":{"source_vertices":vertices.size(),"source_indices":arrays[Mesh.ARRAY_INDEX].size()}})
	for path: String in TRACES:
		var case_span := Chronology.begin("preparation.runner.case", {"capture_source":path})
		var cases_before := _cases.size()
		var failures_before := _failures.size()
		await _case(path, wip, packet)
		Chronology.finish(case_span, {"case_recorded":_cases.size() > cases_before,
			"valid":_failures.size() == failures_before,"work_counts":{"new_failures":_failures.size()-failures_before}})
	span = Chronology.begin("preparation.runner.verify_completion", {})
	_check(FileAccess.get_sha256(LIBRARY) == LIBRARY_HASH, "source weapon file unchanged")
	_check(_cases.size() == 2, "both hands recorded")
	Chronology.finish(span, {"valid":_failures.is_empty(),"case_count":_cases.size()})
	_finish()

func _case(path: String, wip: Resource, packet: Dictionary) -> void:
	var span := Chronology.begin("preparation.runner.verify_capture", {"capture_source":path})
	var capture_matches := _check(FileAccess.get_sha256(path) == TRACES[path], "captured hand hash")
	Chronology.finish(span, {"valid":capture_matches})
	if not capture_matches:
		return
	span = Chronology.begin("preparation.runner.load_capture", {})
	var file := FileAccess.open(path, FileAccess.READ)
	var raw: Variant = file.get_var(false)
	file.close()
	Chronology.finish(span, {"dictionary":raw is Dictionary})
	if not _check(raw is Dictionary and raw.get("valid", false) and raw.get("validation", {}).get("valid", false)
		and raw.get("anatomy_signature") == Config.anatomy.source_signature, "coherent prepared anatomy capture"):
		return
	var selected: Dictionary = {}
	for transaction: Dictionary in raw.transactions:
		if transaction.slot == raw.slot and transaction.get("result", {}).get("applied", false) and not transaction.get("finger_inputs", []).is_empty():
			selected = transaction.finger_inputs[-1]
	if not _check(not selected.is_empty(), "accepted captured placement exists"):
		return
	span = Chronology.begin("preparation.runner.place_fixture", {"slot":raw.slot})
	var stage: Dictionary = _place_saved_fixture(selected, wip, packet)
	Chronology.finish(span, {"valid":stage.get("valid",true),"reason":stage.get("reason","")})
	if not _check(stage.get("valid", true), "saved fixture setup: " + str(stage.get("reason", ""))):
		return
	span = Chronology.begin("preparation.runner.capture_immutable_character", {"slot":stage.slot})
	var immutable_character: PackedByteArray = var_to_bytes(stage.posed_character)
	Chronology.finish(span, {"work_counts":{"bytes":immutable_character.size()}})
	var job := Acquisition.new()
	span = Chronology.begin("preparation.runner.configure_context", {"slot":stage.slot})
	var configured: Dictionary = job.configure(Config.anatomy, stage, Config.contact_config, root)
	Chronology.finish(span, {"valid":configured.get("valid",false),"reason":configured.get("reason","")})
	if not _check(configured.get("valid", false), "context configured"):
		return
	span = Chronology.begin("preparation.runner.prepare_context", {"slot":stage.slot})
	var context: Dictionary = _prepare_hand_context(job, stage)
	Chronology.finish(span, {"valid":context.get("valid",false),"reason":context.get("reason","")})
	if not _check(context.get("valid", false), "prepared hand context: " + str(context.get("reason", ""))):
		return
	context["weapon_to_world"] = stage.object.weapon_to_world
	context["expected_source_body_signature"] = wip.stage2_item_state.primary_grip_handle_body_signature
	context["expected_contact_config"] = Config.contact_config
	# evaluate adds the named calibrated digit planes to the original root chain.
	span = Chronology.begin("preparation.runner.open_candidate", {"slot":stage.slot})
	var candidate: Dictionary = job._builder.evaluate(context.adapter, job._angles(context.open_parameters), Vector3.ZERO, ROOT)
	Chronology.finish(span, {"valid":candidate.get("valid",false),"reason":candidate.get("reason","")})
	if not _check(candidate.get("valid", false), "coherent open pose"):
		return
	span = Chronology.begin("preparation.runner.prepare_sections", {"slot":stage.slot})
	var planes := {}
	for digit: StringName in context.digit_order:
		planes[digit] = {"plane_to_world": candidate.digit_states[digit].plane_to_world,
			"plane_origin_id": candidate.digit_states[digit].plane_origin_id}
	var records: Array = candidate.pose_packet.origin_records.duplicate(true)
	records.append(stage.object.weapon_origin_record)
	var plane_context := {"origin_records": records, "resolve_phase": candidate.pose_packet.resolve_phase,
		"digit_planes": planes, "station_axis_world": context.station_axis_world, "vectors_origin_id": ROOT}
	var surfaces: Dictionary = Sections.new().prepare(wip.stage2_item_state.primary_grip_target_wrapper, packet,
		stage.object.weapon_to_world, candidate.pose_packet.machine_to_world, plane_context, Config.contact_config)
	Chronology.finish(span, {"valid":surfaces.get("valid",false),"reason":surfaces.get("reason","")})
	if not _check(surfaces.get("valid", false), "saved sections prepared: " + str(surfaces.get("reason", ""))):
		return
	print("W3_PREPARATION_START ", stage.slot)
	span = Chronology.begin("preparation.runner.await_solver", {"slot":stage.slot,"scope":"accepted_frozen_fixture"})
	var result: Dictionary = await Follow.new().run(context, surfaces, root)
	Chronology.finish(span, {"slot":stage.slot,"valid":result.get("valid",false),"reason":result.get("reason","")})
	span = Chronology.begin("preparation.runner.verify_case", {"slot":stage.slot})
	var verification_failures_before := _failures.size()
	_check(result.get("valid", false), str(stage.slot) + ": preparation completes: " + str(result.get("reason", "")))
	_check(not result.get("grip_accepted", true), "preparation never claims final grip acceptance")
	_check(var_to_bytes(stage.posed_character) == immutable_character, "captured character remains unchanged")
	if result.get("valid", false):
		_check(result.get("hand_transform_unchanged", false), "fixed hand frame survives preparation")
		var names: Array = []
		var all_in_range := true
		var all_named := true
		var shared_placement_valid := true
		var middle_seat: Variant = null
		var wrapper_match := true
		var caps_unchanged := true
		var wrapper_samples := 0
		var checked_sections := {}
		for sample: Dictionary in result.stages:
			names.append(sample.label)
			all_named = all_named and sample.hand_to_world == candidate.hand_to_world
			var displacement: Vector3 = sample.weapon_to_world.origin - stage.object.weapon_to_world.origin
			shared_placement_valid = shared_placement_valid and sample.weapon_to_world.basis == stage.object.weapon_to_world.basis and absf(displacement.dot(context.station_axis_world)) <= 0.000001
			if sample.label in ["middle_palm_guide_seated","middle_enclosing_target_reached","middle_saved_wrapper_response","middle_saved_wrapper_reseated"]: middle_seat = sample.weapon_to_world
			if str(sample.label).begins_with("follower_"):
				shared_placement_valid = shared_placement_valid and middle_seat != null and sample.weapon_to_world == middle_seat
			for digit: Dictionary in sample.digits:
				var snapshot: Dictionary = context.adapter.digit_inputs[digit.digit].snapshot
				for joint: int in 3:
					all_in_range = all_in_range and digit.angles_rad[joint] >= snapshot.min_angles_rad[joint] and digit.angles_rad[joint] <= snapshot.max_angles_rad[joint]
				all_named = all_named and digit.origin_id == context.adapter.digit_inputs[digit.digit].plane_origin_id
				if digit.get("guide_kind",&"circle")==&"saved_wrapper":
					wrapper_samples+=1
					# Reconstruct the authored displacement through its named axes;
					# subtracting two rounded world origins loses source precision.
					var query_shift: Vector3=context.translation_u_world*sample.placement.x+context.translation_v_world*sample.placement.y
					var key: String=var_to_bytes([digit.digit,query_shift]).hex_encode()
					if not checked_sections.has(key): checked_sections[key]=Sections.new().slice(surfaces,query_shift,ROOT,[digit.digit])
					var source: Dictionary=checked_sections[key]
					wrapper_match=wrapper_match and source.get("valid",false)
					if source.get("valid",false):
						var shape: Dictionary=source.digits[digit.digit]
						wrapper_match=wrapper_match and var_to_bytes(digit.wrapper_polygon)==var_to_bytes(shape.digit_target.polygon) and var_to_bytes(digit.palm_polygon)==var_to_bytes(shape.palm_target.polygon)
					for region: Dictionary in digit.regions:
						var expected: float=0.0025 if region.section==0 else context.observations[digit.digit].caps_m[region.section-1]
						caps_unchanged=caps_unchanged and absf(region.cap_m-expected)<1e-10
				var inverse: Transform3D = (digit.plane_to_world as Transform3D).affine_inverse()
				var joints := PackedVector2Array()
				for point: Vector3 in digit.joints_world:
					var projected: Vector3 = inverse * point
					joints.append(Vector2(projected.x, projected.y))
				digit["joints_m"] = joints
		_check(all_in_range, "every recorded native angle retains prepared limits")
		_check(all_named, "every stage retains fixed Hand and named digit planes")
		_check(shared_placement_valid, "one weapon seat preserves orientation and station; followers cannot move it")
		var bound_states := 0
		var accepted_contacts_valid := true
		for sample: Dictionary in result.stages:
			if sample.get("committed_contact_state", false):
				bound_states += 1
				accepted_contacts_valid = accepted_contacts_valid and sample.accepted_contact_constraints
		_check(accepted_contacts_valid, "committed circle tangency or wrapper physical constraints are verified")
		_check(result.circle_selected.all_required_tangent, "Middle and late palm retain circle contact before saved shape transition")
		_check(result.get("wrapper_target_selected",false) and wrapper_samples>0 and wrapper_match,"active guide uses exact saved Forge target slices without another inset")
		_check(caps_unchanged,"saved target depth never changes per-section physical allowances")
		_check(result.get("material_assessed",false) and result.get("material_safe",false),"final selected skin is measured within physical Handle limits")
		_check(result.get("reseat_attempts",4)<=3,"saved-wrapper reseating stays within three attempts")
		var first_request := -1.0
		for event: Dictionary in result.events:
			if event.event=="coupled_contraction_attempt":
				first_request=event.requested_radius_m
				break
		_check(absf(first_request-Follow.PREPARATION_RADIUS_M)<1e-9,
			"coarse continuation requests 50mm directly rather than a fixed small radius step")
		_check(result.get("preparation_completed", false) and bound_states > 2,
			"coupled Middle contraction reaches enclosing target")
	Chronology.finish(span, {"slot":stage.slot,"valid":_failures.size() == verification_failures_before,
		"work_counts":{"new_failures":_failures.size()-verification_failures_before}})
	span = Chronology.begin("preparation.runner.record_case", {"slot":stage.slot})
	result.erase("candidate")
	result["slot"] = stage.slot
	result["capture_source"] = path
	result["fixture_weapon_to_world"] = stage.object.weapon_to_world
	result["fixture_weapon_origin_record"] = stage.object.weapon_origin_record
	result["fixture_setup"] = stage.fixture_setup
	_cases.append(result)
	print("W3_PREPARATION_RESULT ", JSON.stringify({"slot":stage.slot,"valid":result.get("valid"),
		"total_ms":result.get("total_ms"),"native_process_count":result.get("native_process_count"),
		"stage_count":result.get("stages",[]).size()}))
	Chronology.finish(span, {"slot":stage.slot,"case_count":_cases.size()})
	await process_frame

func _prepare_hand_context(job: RefCounted, stage: Dictionary) -> Dictionary:
	# W3 needs prepared skin/hinges, not the old per-slice envelope builder.
	var span := Chronology.begin("preparation.runner.prepare_adapter", {"slot":stage.slot})
	var adapter: Dictionary = job._builder.prepare(Config.anatomy, stage.posed_character, stage.slot, job._selected_digits())
	Chronology.finish(span, {"valid":adapter.get("valid",false),"reason":adapter.get("reason","")})
	if not adapter.get("valid", false): return adapter
	var frame: Transform3D = stage.object.weapon_to_world
	var axis: Vector3 = (frame.basis * (stage.object.primary_grip_span_end_local - stage.object.primary_grip_span_start_local)).normalized()
	var plane: Transform3D = adapter.digit_inputs[&"middle"].plane_to_world
	var u: Vector3 = plane.basis.z.cross(axis)
	if u.length_squared() < 1e-8: u = plane.basis.x - axis * plane.basis.x.dot(axis)
	if u.length_squared() < 1e-8: return {"valid":false,"reason":"degenerate_shared_translation_basis"}
	u = u.normalized()
	var observations := {}
	for digit: StringName in job._selected_digits():
		span = Chronology.begin("preparation.runner.prepare_digit_observer", {"slot":stage.slot,"digit":digit})
		var observed: Dictionary = job._observer.prepare(adapter, digit)
		Chronology.finish(span, {"valid":observed.get("valid",false),"reason":observed.get("reason","")})
		if not observed.get("valid", false): return observed
		observations[digit] = observed
	var context := {"valid":true,"adapter":adapter,"slot":stage.slot,"digit_order":job._selected_digits(),
		"observations":observations,"station_axis_world":axis,"translation_u_world":u,
		"translation_v_world":axis.cross(u).normalized(),"vectors_origin_id":ROOT}
	span = Chronology.begin("preparation.runner.prepare_circle_context", {"slot":stage.slot})
	context = Acquisition.op_circle_prepare(job, Config.anatomy, stage, context)
	Chronology.finish(span, {"valid":context.get("valid",false),"reason":context.get("reason","")})
	if not context.get("valid", false): return context
	span = Chronology.begin("preparation.runner.prepare_palm_region", {"slot":stage.slot})
	context["palm_region"] = Palm.new().prepare(context, Config.anatomy)
	Chronology.finish(span, {"valid":context.palm_region.get("valid",false),"reason":context.palm_region.get("reason","")})
	if not context.palm_region.get("valid", false): return context.palm_region
	return context

func _place_saved_fixture(source: Dictionary, wip: Resource, packet: Dictionary) -> Dictionary:
	var stage: Dictionary = source.duplicate(true)
	var old: Dictionary = source.object
	var source_axis: Vector3 = (old.primary_grip_span_end_local - old.primary_grip_span_start_local).normalized()
	var frame: Transform3D = old.weapon_to_world * Transform3D(Basis(Quaternion(Vector3.RIGHT, source_axis)),
		(old.primary_grip_span_start_local + old.primary_grip_span_end_local) * 0.5)
	var original_frame := frame
	var profile: Resource = wip.latest_baked_profile_snapshot
	var cell: float = wip.stage2_item_state.cell_world_size_meters
	var adapter: Dictionary = Candidate.new().prepare(Config.anatomy, source.posed_character, source.slot, [&"middle"])
	if not adapter.get("valid", false): return adapter
	var middle: Dictionary = adapter.digit_inputs[&"middle"]
	var plane: Transform3D = middle.plane_to_world
	var saved_axis: Vector3 = (frame.basis * (profile.primary_grip_span_end - profile.primary_grip_span_start)).normalized()
	var denominator: float = plane.basis.z.dot(saved_axis)
	if absf(denominator) < 0.000001: return {"valid":false,"reason":"fixture_axis_parallel_to_middle_plane"}
	var midpoint: Vector3 = frame * ((profile.primary_grip_span_start + profile.primary_grip_span_end) * cell * 0.5)
	var axial_setup_m: float = plane.basis.z.dot(plane.origin - midpoint) / denominator
	frame.origin += saved_axis * axial_setup_m
	stage["fixture_setup"] = {"policy":"saved_span_midpoint_on_captured_middle_plane",
		"original_weapon_to_world":original_frame,"middle_plane_origin_id":middle.plane_origin_id,
		"middle_plane_to_world":plane,"axial_setup_m":axial_setup_m,
		"axis_world":saved_axis,"axis_origin_id":ROOT,"runtime_axial_seating_allowed":false}
	var record := {"origin_id": Packet.VERTICES_ORIGIN_ID, "parent_origin_id": ROOT,
		"transform_to_parent": (source.posed_character.machine_to_world as Transform3D).affine_inverse() * frame,
		"owner_system": &"w3_saved_handle_fixture", "resolve_phase": source.posed_character.resolve_phase,
		"space_type": &"weapon", "is_dynamic": true}
	var mesh_id := &"W3SavedPhysicalHandleMeshOrigin"
	var mesh_record := {"origin_id": mesh_id, "parent_origin_id": Packet.VERTICES_ORIGIN_ID,
		"transform_to_parent": Transform3D.IDENTITY, "owner_system": &"w3_saved_handle_fixture",
		"resolve_phase": source.posed_character.resolve_phase, "space_type": &"presentation", "is_dynamic": false}
	var faces := PackedVector3Array()
	for index: int in packet.primary_grip_handle_indices:
		faces.append(packet.primary_grip_handle_vertices[index])
	stage.object = {"local_faces": faces, "local_faces_origin_id": mesh_id, "origin_record": mesh_record,
		"weapon_origin_record": record, "mesh_to_world": frame, "weapon_to_world": frame,
		"primary_grip_span_start_local": profile.primary_grip_span_start * cell,
		"primary_grip_span_end_local": profile.primary_grip_span_end * cell,
		"primary_grip_span_start_origin_id": Packet.VERTICES_ORIGIN_ID,
		"primary_grip_span_end_origin_id": Packet.VERTICES_ORIGIN_ID}
	return stage

func _check(ok: bool, label: String) -> bool:
	_checks += 1
	Chronology.event("preparation.runner.check", {"valid":ok,"label":label})
	if not ok:
		_failures.append(label)
		push_error(label)
	return ok

func _finish() -> void:
	var report_span := Chronology.begin("preparation.runner.write_reports", {"report_prefix":_prefix})
	var report := {"schema":"contact_driven_preparation_report_v1", "checks":_checks,"failures":_failures,
		"cases":_cases,"total_ms":float(Time.get_ticks_usec()-_started)/1000.0,
		"source_library":LIBRARY,"source_library_sha256":LIBRARY_HASH,
		"scope":"W3 coarse circle preparation plus W4 exact saved-wrapper/planar-material attempt; no full 3D grip or live integration", "production_pose_written":false}
	var span := Chronology.begin("preparation.runner.write_json", {})
	var file := FileAccess.open(_prefix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(_json(report), "\t"))
	file.close()
	Chronology.finish(span, {})
	span = Chronology.begin("preparation.runner.write_html", {})
	var template: String = FileAccess.get_file_as_string("res://tools/grip_plane_proof/contact_driven_preparation_view.html")
	file = FileAccess.open(_prefix + ".html", FileAccess.WRITE)
	file.store_string(template.replace("__REPORT__", JSON.stringify(_json(report)).replace("<", "\\u003c")))
	file.close()
	Chronology.finish(span, {})
	Chronology.finish(report_span, {"json_path":_prefix+".json","html_path":_prefix+".html"})
	print("W3_REPORT=", _prefix + ".json")
	print("W3_PREPARATION_STRUCTURE: ", "PASS" if _failures.is_empty() else "FAIL", " checks=", _checks)
	Chronology.finish(_trace_run_span, {"valid":_failures.is_empty(),"case_count":_cases.size(),"checks":_checks,
		"work_counts":{"failures":_failures.size()}})
	Chronology.event("preparation.runner.complete", {"scope":"accepted_frozen_fixture","valid":_failures.is_empty(),
		"case_count":_cases.size(),"exit_code":0 if _failures.is_empty() else 1,"grip_success_asserted":false})
	Chronology.close()
	quit(0 if _failures.is_empty() else 1)

func _json(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for key: Variant in value: out[str(key)] = _json(value[key])
		return out
	if value is Vector2: return [value.x,value.y]
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Transform3D: return {"origin":_json(value.origin),"basis":[_json(value.basis.x),_json(value.basis.y),_json(value.basis.z)]}
	if value is float and not is_finite(value): return null
	if value is Array or value is PackedVector2Array or value is PackedVector3Array or value is PackedFloat64Array or value is PackedFloat32Array or value is PackedInt32Array or value is PackedStringArray:
		var out: Array = []
		for item: Variant in value: out.append(_json(item))
		return out
	return value
