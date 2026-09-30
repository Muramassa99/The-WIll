extends SceneTree

## Bounded W1 proof: saved 3D targets are separate from physical Handle geometry.
## No character, IK search, gameplay save, or live grip acceptance is involved.
## API references checked before implementation:
## https://docs.godotengine.org/en/4.7/classes/class_resource.html
## https://docs.godotengine.org/en/4.7/classes/class_resourceloader.html
## https://docs.godotengine.org/en/4.7/classes/class_resourcesaver.html
const Fixture = preload("res://tools/grip_plane_proof/linear_handle_template_fixture.gd")
const Profiles = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const Authoring = preload("res://runtime/forge_v2/forge_v2_authoring_state.gd")
const Stage = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const Presenter = preload("res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd")
const Baker = preload("res://runtime/forge_v2/forge_v2_grip_target_wrapper_baker.gd")
const Resolver = preload("res://core/resolvers/prepared_grip_target_wrapper_resolver.gd")
const HandlePacket = preload("res://core/resolvers/primary_grip_handle_mesh_packet.gd")
const Adapter = preload("res://runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd")
const Wip = preload("res://core/models/crafted_item_wip.gd")
const Library = preload("res://core/models/player_forge_wip_library_state.gd")
const Forge = preload("res://services/forge_service.gd")
const Section = preload("res://runtime/player/grip/prepared_weapon_plane_section.gd")
const CONFIG: Resource = preload("res://core/defs/characters/josie/grip_contact_config.tres")
const RULES: Resource = preload("res://core/defs/forge/forge_rules_default.tres")
const PROFILE_ID := "handle_profile_1787891232.544_14"
const WORKSPACE_OUTPUT := "C:/WORKSPACE/test_artifacts/"
const ROOT_ORIGIN := &"RL_BoneRoot"
const WEAPON_ORIGIN := &"WeaponRootOrigin"
const OUTLINE_TOLERANCE_M := 0.00005
var _checks: int = 0
var _failures: Array[String] = []
var _cases: Array = []
var _slices: Array = []
var _output_prefix: String
var _started: int
var _bake_calls: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_started = Time.get_ticks_usec()
	_output_prefix = WORKSPACE_OUTPUT + "forge_v2_grip_target_wrapper_" + Time.get_datetime_string_from_system().replace(":", "-")
	var fixture: Dictionary = Fixture.new().load_profile(PROFILE_ID)
	if not _check(fixture.get("valid", false), "saved concave profile loads with frozen source hash"):
		_finish(); return
	var config: Dictionary = CONFIG.get("contact_config").duplicate(true)
	for case_name: String in ["straight", "curved"]:
		await _test_case(case_name, fixture, config)
	_check(FileAccess.get_sha256(Fixture.SOURCE_PATH) == Fixture.SOURCE_SHA256, "saved profile source remains unchanged")
	_check(_cases.size() == 2 and _slices.size() == 8, "both path fixtures produce all four shared-plane comparisons")
	_finish()


func _test_case(case_name: String, fixture: Dictionary, config: Dictionary) -> void:
	var built: Dictionary = _build_fixture(case_name, fixture)
	if not _check(built.get("valid", false), case_name + ": committed Handle fixture"):
		return
	var body: Resource = built.body
	var source_body_signature: String = HandlePacket.build_body_signature(body)
	var presenter: Node3D = Presenter.new()
	root.add_child(presenter)
	var packet: Dictionary = {}
	for _frame: int in range(120):
		packet = presenter.call("_resolve_authoritative_protected_handle_packet", body)
		if not packet.get("pending", false): break
		await process_frame
	if not _check(packet.get("ok", false), case_name + ": actual protected Handle CSG packet: " + str(packet.get("reason", ""))):
		presenter.free(); return
	var material_before: PackedByteArray = var_to_bytes(packet)
	var stage: Node = Stage.new()
	root.add_child(stage)
	stage.set("active_authoring_state", built.state)
	built.state.call("set_runtime_contract_mesh_export_provider", func() -> Dictionary: return packet.duplicate(true))
	stage.call("set_grip_target_wrapper_export_provider", _bake_target.bind(presenter))
	_check(stage.call("build_crafted_item_wip_for_save", &"verify_incomplete_wrapper", "Incomplete wrapper", packet) == null,
		case_name + ": a new valid-Handle save cannot persist before target preparation")
	var began := Time.get_ticks_usec()
	var result: Dictionary = await stage.call("prepare_pending_work_for_save")
	var bake_ms: float = float(Time.get_ticks_usec() - began) / 1000.0
	if not _check(result.get("ok", false), case_name + ": wrapper bake: " + str(result.get("reason", ""))):
		stage.free(); presenter.free(); return
	var wrapper: Resource = result.get("runtime_mesh_packet", {}).get("primary_grip_target_wrapper")
	if not _check(wrapper != null, case_name + ": save preparation publishes prepared target with material packet"):
		stage.free(); presenter.free(); return
	var calls_before_reuse: int = _bake_calls
	var repeated: Dictionary = await stage.call("prepare_pending_work_for_save")
	_check(repeated.get("ok", false) and _bake_calls == calls_before_reuse, case_name + ": unchanged save preparation reuses cached target")
	_check(HandlePacket.build_body_signature(body) == source_body_signature, case_name + ": source body and its frame are unchanged")
	_check(var_to_bytes(packet) == material_before, case_name + ": actual Handle packet is byte-for-byte unchanged")
	_check(_valid(wrapper, packet, config), case_name + ": prepared wrapper validates against source and character parameters")
	_check(wrapper.get("vertices_origin_id") == WEAPON_ORIGIN, case_name + ": target coordinates have the same explicit WeaponRoot origin as material")
	_test_rejection(case_name, wrapper, packet, config)
	var geometry_hash := _geometry_hash(wrapper)
	var section_reports := _test_sections(case_name, body, packet, wrapper)
	_test_profile_geometry(case_name, wrapper, config)
	_test_persistence(case_name, stage, built.state, packet, wrapper, config)
	_check(_geometry_hash(wrapper) == geometry_hash, case_name + ": slicing and persistence do not modify wrapper geometry")
	_cases.append({"name": case_name, "profile_id": PROFILE_ID, "profile_label": fixture.metadata.profile_label,
		"source_body_signature": source_body_signature, "target_geometry_sha256": geometry_hash,
		"bake_ms": bake_ms, "actual_triangles": packet.primary_grip_handle_indices.size() / 3,
		"digit_target_triangles": wrapper.get("target_indices").size() / 3,
		"palm_target_triangles": wrapper.get("palm_target_indices").size() / 3,
		"sections": section_reports})
	stage.free()
	presenter.free()


func _bake_target(body: Resource, packet: Dictionary, config: Dictionary, presenter: Node3D) -> Dictionary:
	_bake_calls += 1
	# Exercise both accepted configuration representations across the two bakes.
	var supplied := config.duplicate(true)
	if _bake_calls == 2:
		supplied["inward_min_radius_m"] = supplied.envelope_radius_m
		supplied.erase("envelope_radius_m")
	return await Baker.new().bake(presenter, body, packet, supplied)


func _build_fixture(case_name: String, fixture: Dictionary) -> Dictionary:
	# These are authoring-local meters. The protected packet binds the same
	# coordinates to WeaponRootOrigin. Test placement in RL_BoneRoot is identity.
	var points := PackedVector3Array([Vector3(-0.19, 0, 0), Vector3.ZERO, Vector3(0.19, 0, 0)])
	if case_name == "curved": points[1] = Vector3(0, 0.025, 0)
	var state: Resource = Authoring.new()
	state.call("reset_new_draft", "Grip target wrapper verification " + case_name)
	state.call("set_active_tool_id", Authoring.TOOL_HANDLES)
	var entries: Array = Profiles.build_handle_profile_entries()
	if entries.is_empty(): return {"valid": false}
	state.call("set_active_profile_id", StringName(entries[0].id))
	state.call("set_active_handle_rounding_enabled", false)
	for point: Vector3 in points:
		if int(state.call("append_spline_line_point", point, Vector3.UP)) < 0: return {"valid": false}
	if not state.call("generate_profile_extrusion_from_spline"): return {"valid": false}
	var body: Resource = state.call("get_selected_material_body")
	if body == null: return {"valid": false}
	var runtime: Dictionary = fixture.runtime
	body.set("profile_id", StringName(PROFILE_ID))
	body.set("profile_display_name", fixture.metadata.profile_label)
	body.set("profile_polygon_2d_meters", runtime.deposition_polygon_2d_meters)
	body.set("profile_anchor_2d_meters", runtime.anchor_2d_meters)
	body.set("profile_contact_point_relative_2d_meters", runtime.contact_point_relative_2d_meters)
	body.set("profile_contact_direction_2d", runtime.contact_direction_2d)
	body.set("profile_contact_distance_meters", runtime.contact_distance_meters)
	body.set("profile_runtime_schema_version", runtime.schema_version)
	body.set("profile_rotation_bias_degrees", float(fixture.profile.get("rotation_degrees", 0.0)))
	body.set("profile_twist_degrees_per_meter", 0.0)
	body.set("handle_profile_authoring_snapshot", fixture.profile.duplicate(true))
	body.call("normalize")
	if state.call("commit_material_body_as_layer", body.get("body_id")) == null: return {"valid": false}
	return {"valid": true, "state": state, "body": body}


func _test_sections(case_name: String, body: Resource, packet: Dictionary, wrapper: Resource) -> Array:
	var reports: Array = []
	var paths: PackedVector3Array = body.get("path_points")
	var actual := _faces(packet.primary_grip_handle_vertices, packet.primary_grip_handle_indices)
	var target := _faces(wrapper.get("target_vertices_m"), wrapper.get("target_indices"))
	var palm := _faces(wrapper.get("palm_target_vertices_m"), wrapper.get("palm_target_indices"))
	for segment: int in range(2):
		var tangent: Vector3 = (paths[segment + 1] - paths[segment]).normalized()
		var frame: Dictionary = Profiles.resolve_profile_path_frame(tangent, Vector3.UP,
			body.get("profile_contact_direction_2d"), float(body.get("profile_rotation_bias_degrees")))
		var basis := Basis(frame.axis_x, frame.axis_y, frame.tangent)
		for oblique: bool in [false, true]:
			var plane_basis: Basis = basis * Basis(Vector3.UP, deg_to_rad(35.0)) if oblique else basis
			var plane := Transform3D(plane_basis, paths[segment].lerp(paths[segment + 1], 0.47))
			var label := "%s / span %d / %s" % [case_name, segment + 1, "35 degree oblique" if oblique else "perpendicular"]
			var origin_id := StringName("GripTargetWrapperVerificationPlane_" + case_name + "_" + str(segment) + "_" + str(oblique))
			var sections: Dictionary = {}
			for kind: String in ["material", "digit_target", "palm_target"]:
				var triangles: PackedVector3Array = actual if kind == "material" else (target if kind == "digit_target" else palm)
				var helper := Section.new()
				var prepared: Dictionary = helper.prepare({"valid": true, "triangles_world": triangles,
					"surface_source_origin_id": WEAPON_ORIGIN, "resolved_world_origin_id": ROOT_ORIGIN}, plane, origin_id)
				var section: Dictionary = helper.slice(prepared, plane)
				_check(section.get("valid", false), label + ": complete " + kind + " slice: " + str(section.get("reason", "")))
				sections[kind] = section
			if not sections.material.get("valid", false) or not sections.digit_target.get("valid", false) or not sections.palm_target.get("valid", false):
				continue
			if case_name == "straight" and not oblique:
				for check_kind: String in ["material", "digit_target", "palm_target"]:
					var profile_key := "source_profile_m" if check_kind == "material" else ("target_profile_m" if check_kind == "digit_target" else "palm_target_profile_m")
					var maximum_error := 0.0
					for point: Vector2 in wrapper.get(profile_key):
						# Exact Handle CSG mapping mirrors authored X. This checks
						# the baked slice against that independent established rule.
						maximum_error = maxf(maximum_error, _distance_to_polygon(Vector2(-point.x, point.y), sections[check_kind].polygon))
					_check(maximum_error <= OUTLINE_TOLERANCE_M, label + ": " + check_kind + " preserves final Handle orientation and size; error m=" + str(maximum_error))
			var report := {"label": label, "plane_origin_id": origin_id, "source_origin_id": WEAPON_ORIGIN,
				"resolved_world_origin_id": ROOT_ORIGIN, "weapon_to_world": "identity fixture transform",
				"plane_origin_m": _v3(plane.origin), "plane_basis": [_v3(plane.basis.x), _v3(plane.basis.y), _v3(plane.basis.z)],
				"material": _points(sections.material.polygon), "digit_target": _points(sections.digit_target.polygon),
				"palm_target": _points(sections.palm_target.polygon)}
			_slices.append(report); reports.append(report)
	return reports


func _test_profile_geometry(case_name: String, wrapper: Resource, config: Dictionary) -> void:
	var source: PackedVector2Array = wrapper.get("source_profile_m")
	var envelope: PackedVector2Array = wrapper.get("envelope_profile_m")
	var digit: PackedVector2Array = wrapper.get("target_profile_m")
	var palm: PackedVector2Array = wrapper.get("palm_target_profile_m")
	_check(Profiles.calculate_polygon_area_meters_squared(envelope) > Profiles.calculate_polygon_area_meters_squared(source), case_name + ": concave recesses are bridged before inset")
	for entry: Array in [["digit", digit, float(config.guide_inward_target_offset_m)], ["palm", palm, float(config.palm_guide_target_depth_m)]]:
		var minimum_distance := INF
		var all_inside := true
		for point: Vector2 in entry[1]:
			all_inside = all_inside and Geometry2D.is_point_in_polygon(point, envelope)
			minimum_distance = minf(minimum_distance, _distance_to_polygon(point, envelope))
		_check(all_inside, case_name + ": " + entry[0] + " attraction target is inset inside envelope")
		_check(absf(minimum_distance - float(entry[2])) <= OUTLINE_TOLERANCE_M,
			case_name + ": " + entry[0] + " measured minimum inset matches configured depth (m): " + str(minimum_distance))


func _test_rejection(case_name: String, wrapper: Resource, packet: Dictionary, config: Dictionary) -> void:
	var stale_source: Dictionary = packet.duplicate(true)
	stale_source.primary_grip_handle_body_signature += ":stale"
	_check(not _valid(wrapper, stale_source, config), case_name + ": stale Handle signature rejected")
	stale_source = packet.duplicate(true)
	stale_source.primary_grip_handle_vertices[0] += Vector3(0.001, 0, 0)
	_check(not _valid(wrapper, stale_source, config), case_name + ": changed actual Handle vertices rejected")
	for field: String in ["envelope_radius_m", "guide_inward_target_offset_m", "palm_guide_target_depth_m"]:
		var changed: Dictionary = config.duplicate(true)
		changed[field] = float(changed[field]) + 0.001
		_check(not _valid(wrapper, packet, changed), case_name + ": stale " + field + " rejected")
	var changed_anatomy: Dictionary = config.duplicate(true)
	changed_anatomy.anatomy_signature += ":stale"
	_check(not _valid(wrapper, packet, changed_anatomy), case_name + ": changed anatomy signature rejected")
	var wrong_origin: Resource = wrapper.duplicate(true)
	wrong_origin.set("vertices_origin_id", &"AnonymousWrongOrigin")
	_check(not _valid(wrong_origin, packet, config), case_name + ": wrong target coordinate origin rejected")


func _test_persistence(case_name: String, stage: Node, state: Resource, packet: Dictionary, wrapper: Resource, config: Dictionary) -> void:
	var wip: CraftedItemWIP = Wip.new()
	wip.wip_id = StringName("verify_grip_target_wrapper_" + case_name)
	wip.forge_project_name = "Grip target wrapper verifier " + case_name
	wip.creator_id = &"verify"
	wip.forge_builder_path_id = Wip.BUILDER_PATH_MELEE
	wip.forge_builder_component_id = Wip.BUILDER_COMPONENT_PRIMARY
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.forge_v2_authoring_state = state.duplicate(true)
	wip.layers = []
	wip.ensure_combat_animation_station_state()
	var prepared_packet: Dictionary = packet.duplicate(true)
	prepared_packet["primary_grip_target_wrapper"] = wrapper
	# A once-valid packet cannot be applied to a handle edited after preparation.
	var live_body: Resource = Adapter.resolve_valid_handle_body(state).get("body")
	var old_polygon: PackedVector2Array = live_body.get("profile_polygon_2d_meters").duplicate()
	var changed_polygon := old_polygon.duplicate()
	changed_polygon[0] += Vector2(0.0001, 0)
	live_body.set("profile_polygon_2d_meters", changed_polygon)
	_check(stage.call("build_crafted_item_wip_for_save", StringName("stale_test"), "Stale", prepared_packet) == null,
		case_name + ": save refuses a packet from before the current Handle edit")
	live_body.set("profile_polygon_2d_meters", old_polygon)
	var contract: Dictionary = Adapter.build_runtime_contract(wip, prepared_packet, 0.0125)
	if not _check(contract.get("valid", false), case_name + ": adapter accepts target alongside real material: " + str(contract.get("error", ""))): return
	wip.stage2_item_state = contract.stage2_item_state
	wip.latest_baked_profile_snapshot = contract.baked_profile
	if not _check(wip.stage2_item_state.get("primary_grip_target_wrapper") != null, case_name + ": adapter retains wrapper in Stage2"): return
	var library: Resource = Library.new()
	var library_path := _output_prefix + "_" + case_name + "_library.tres"
	library.set("save_file_path", library_path)
	var saved: CraftedItemWIP = stage.call("save_current_wip_as", library, "Prepared target " + case_name, prepared_packet)
	if not _check(saved != null and FileAccess.file_exists(library_path), case_name + ": real Save As persists prepared target into isolated library"): return
	var saved_id := saved.wip_id
	saved = stage.call("save_current_wip", library, prepared_packet)
	if not _check(saved != null and saved.wip_id == saved_id, case_name + ": real Save retains target and saved identity"): return
	var loaded: Resource = ResourceLoader.load(library_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not _check(loaded != null, case_name + ": isolated library reload bypasses resource cache"): return
	var reloaded: CraftedItemWIP = loaded.call("get_saved_wip_clone", saved.wip_id, true)
	if not _check(reloaded != null and reloaded.stage2_item_state != null, case_name + ": persisted Stage2 reloaded"): return
	var restored: Resource = reloaded.stage2_item_state.get("primary_grip_target_wrapper")
	if not _check(restored != null, case_name + ": persisted wrapper restored"): return
	_check(_valid(restored, packet, config), case_name + ": reloaded wrapper source/config still valid")
	_check(_geometry_hash(restored) == _geometry_hash(wrapper), case_name + ": all target triangles survive save/reload exactly")
	var forge: ForgeService = Forge.new(RULES)
	var baked: BakedProfile = forge.bake_wip(reloaded, {})
	_check(baked != null and baked.primary_grip_valid, case_name + ": fresh ForgeService rebake retains valid physical Handle")
	var after_rebake: Resource = reloaded.stage2_item_state.get("primary_grip_target_wrapper")
	_check(after_rebake != null and _valid(after_rebake, packet, config), case_name + ": runtime rebake retains prepared wrapper without new wrapping")
	if after_rebake != null:
		_check(_geometry_hash(after_rebake) == _geometry_hash(wrapper), case_name + ": runtime rebake does not replace or distort target triangles")


func _valid(wrapper: Resource, packet: Dictionary, config: Dictionary) -> bool:
	var result: Dictionary = Resolver.validate(wrapper, packet, config)
	return bool(result.get("valid", result.get("ok", false)))


func _geometry_hash(wrapper: Resource) -> String:
	var values: Array = []
	for field: String in ["target_vertices_m", "target_indices", "palm_target_vertices_m", "palm_target_indices"]:
		values.append(wrapper.get(field))
	return var_to_bytes(values).hex_encode().sha256_text()


func _faces(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var output := PackedVector3Array()
	for index: int in indices: output.append(vertices[index])
	return output


func _distance_to_polygon(point: Vector2, polygon: PackedVector2Array) -> float:
	var result := INF
	for index: int in polygon.size():
		result = minf(result, point.distance_to(Geometry2D.get_closest_point_to_segment(point, polygon[index], polygon[(index + 1) % polygon.size()])))
	return result


func _points(points: PackedVector2Array) -> Array:
	var output: Array = []
	for point: Vector2 in points: output.append([point.x, point.y])
	return output


func _v3(point: Vector3) -> Array:
	return [point.x, point.y, point.z]


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)
	return condition


func _finish() -> void:
	var report := {"schema": "forge_v2_grip_target_wrapper_verification_v1", "ok": _failures.is_empty(),
		"checks": _checks, "failures": _failures, "cases": _cases,
		"source_library": Fixture.SOURCE_PATH, "source_library_sha256": Fixture.SOURCE_SHA256,
		"total_ms": float(Time.get_ticks_usec() - _started) / 1000.0,
		"production_save_written": false, "hand_solve_run": false, "grip_accepted": false}
	var json_file := FileAccess.open(_output_prefix + ".json", FileAccess.WRITE)
	if json_file == null: push_error("Cannot write wrapper verification JSON"); quit(1); return
	json_file.store_string(JSON.stringify(report, "\t")); json_file.close()
	var html_file := FileAccess.open(_output_prefix + ".html", FileAccess.WRITE)
	if html_file == null: push_error("Cannot write wrapper verification HTML"); quit(1); return
	html_file.store_string(_html(report)); html_file.close()
	if not _slices.is_empty():
		var picture := Image.new()
		var svg := _svg(_slices[0]).replace("<svg ", "<svg xmlns='http://www.w3.org/2000/svg' width='480' height='460' ")
		if picture.load_svg_from_string(svg) == OK:
			picture.save_png(_output_prefix + "_straight_slice.png")
	print("GRIP_TARGET_WRAPPER_RESULT=" + _output_prefix + ".json")
	print("GRIP_TARGET_WRAPPER_HTML=" + _output_prefix + ".html")
	print("GRIP_TARGET_WRAPPER_SUMMARY=" + JSON.stringify({"ok": report.ok, "checks": _checks, "failures": _failures, "total_ms": report.total_ms}))
	quit(0 if report.ok else 1)


func _html(report: Dictionary) -> String:
	var html := "<!doctype html><meta charset='utf-8'><title>Forge V2 prepared grip targets</title><style>body{font:16px system-ui;background:#eef1f5;color:#172a40;margin:24px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(420px,1fr));gap:20px}article{background:white;padding:20px;border:1px solid #bcc8d5}svg{width:100%;height:auto}h2{font-size:18px}.material{color:#555}.digit{color:#bd0083}.palm{color:#008d83}</style>"
	html += "<h1>Forge V2: prepared Handle target surfaces</h1><p>" + ("Checks passed." if report.ok else "Checks failed; see JSON report.") + " This compares saved 3D tube slices. No hand solve or live grip acceptance.</p>"
	html += "<p><b class='material'>Grey: actual Handle material / overlap authority</b> · <b class='digit'>Magenta: digit attraction target (1.5 mm inset)</b> · <b class='palm'>Teal: palm attraction target (3 mm inset)</b>.</p><p>Each panel cuts all three surfaces with the same plane. Recess bridges can lie outside material; target surfaces are not collision limits. Equal X/Y scale; all dimensions in mm.</p><main>"
	for section: Dictionary in _slices:
		html += "<article><h2>" + section.label.xml_escape() + "</h2>" + _svg(section) + "<p>Origin: " + String(section.plane_origin_id).xml_escape() + "</p></article>"
	return html + "</main>"


func _svg(section: Dictionary) -> String:
	var scale: float = 4.5
	var svg := "<svg viewBox='0 0 480 460' role='img'>"
	for kind: String in ["material", "digit_target", "palm_target"]:
		var coordinates := PackedStringArray()
		for point: Array in section[kind]: coordinates.append("%.3f,%.3f" % [240.0 + float(point[0]) * 1000.0 * scale, 220.0 - float(point[1]) * 1000.0 * scale])
		var color := "#555" if kind == "material" else ("#bd0083" if kind == "digit_target" else "#008d83")
		svg += "<polygon points='%s' stroke='%s' fill='%s' stroke-width='1.7'/>" % [" ".join(coordinates), color, "#c6cbd2" if kind == "material" else "none"]
	svg += "<path d='M20 425h45' stroke='#172a40' stroke-width='3'/><text x='20' y='447' font-size='13'>10 mm</text><path d='M435 400h25m-25 0v-25' stroke='#526577' fill='none'/><text x='456' y='417' font-size='12'>X</text><text x='419' y='374' font-size='12'>Y</text>"
	return svg + "</svg>"
