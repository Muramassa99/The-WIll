extends SceneTree

# Real authoring/history and protected material/target geometry, with isolated
# resources. Does not load player libraries or run a character/grip solve.
const Authoring = preload("res://runtime/forge_v2/forge_v2_authoring_state.gd")
const Stage = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const Profiles = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const Presenter = preload("res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd")
const Roll = preload("res://runtime/forge_v2/forge_v2_path_roll.gd")
const Packet = preload("res://core/resolvers/primary_grip_handle_mesh_packet.gd")
const Baker = preload("res://runtime/forge_v2/forge_v2_grip_target_wrapper_baker.gd")
const Validation = preload("res://core/resolvers/prepared_grip_target_wrapper_resolver.gd")
const Adapter = preload("res://runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd")
const Section = preload("res://runtime/player/grip/prepared_weapon_plane_section.gd")
const Wip = preload("res://core/models/crafted_item_wip.gd")
const CONFIG = preload("res://core/defs/characters/josie/grip_contact_config.tres")
const OUTPUT := "C:/WORKSPACE/test_artifacts/forge_v2_point_twist_20261017.json"
var checks := 0
var failures := PackedStringArray()
var evidence: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var started := Time.get_ticks_usec()
	_test_state()
	_test_history()
	_test_roll_geometry()
	_test_smooth_roll_constraints()
	await _test_actual_handle_and_wrapper()
	var report := {"ok": failures.is_empty(), "checks": checks,
		"failures": failures, "evidence": evidence,
		"duration_ms": float(Time.get_ticks_usec() - started) / 1000.0}
	DirAccess.make_dir_recursive_absolute(OUTPUT.get_base_dir())
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t") + "\n")
	for failure: String in failures: push_error(failure)
	print("Forge V2 point twist: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _state() -> Resource:
	var state: Resource = Authoring.new()
	state.call("reset_new_draft", "Point twist verification")
	state.call("set_active_tool_id", Authoring.TOOL_HANDLES)
	state.call("set_active_profile_id", Profiles.PROFILE_HANDLE_BUILDER)
	state.call("set_active_handle_path_mode_id", Authoring.HANDLE_PATH_MODE_THREE_POINT_LINEAR)
	for point: Vector3 in [Vector3(-0.1, 0, 0), Vector3.ZERO, Vector3(0.1, 0, 0)]:
		state.call("append_spline_line_point", point, Vector3.UP)
	return state


func _roll_at(state: Resource, index: int) -> float:
	return float(state.call("get_spline_line_point_roll_degrees", index))


func _test_state() -> void:
	var state := _state()
	_check(state.get("spline_line_roll_degrees") == PackedFloat64Array([0, 0, 0]), "old/default authoring has zero rolls")
	_check(bool(state.call("set_spline_line_point_roll_degrees", 1, 3600.0)), "accept ten complete middle turns")
	_check(_roll_at(state, 1) == 3600.0 and _roll_at(state, 0) == 0.0 and _roll_at(state, 2) == 0.0,
		"ten turns retained without moving neighbor rolls")
	state.call("set_spline_line_point_roll_degrees", 1, 144000.0)
	_check(_roll_at(state, 1) == 3600.0, "smooth middle reversal clamps peak to keep local pitch at least5mm")
	state.call("set_spline_line_point_roll_degrees", 1, -144000.0)
	_check(_roll_at(state, 1) == -3600.0, "negative density bound is symmetric")
	state.call("set_spline_line_point_roll_degrees", 1, 89.7)
	_check(_roll_at(state, 1) == 90.0, "wholedegree input retains quarterturn")
	var before := state.get("spline_line_roll_degrees") as PackedFloat64Array
	state.call("set_spline_line_point_roll_degrees", 1, NAN)
	_check(state.get("spline_line_roll_degrees") == before, "nonfinite input does not corrupt authored roll")
	state.call("set_spline_line_point_roll_degrees", 1, 7200.0)
	var original_points := (state.get("spline_line_points") as PackedVector3Array).duplicate()
	_check(not bool(state.call("set_spline_line_point", 1, Vector3(-0.05, 0, 0))), "shortening maxdensity span is rejected")
	_check(state.get("spline_line_points") == original_points and _roll_at(state, 1) == 3600.0,
		"rejected move preserves geometry and fullturns")
	state.call("select_spline_line_point", 2)
	state.call("select_next_spline_line_point", 1)
	_check(int(state.get("selected_spline_point_index")) == 0, "next wraps last tofirst")
	state.call("select_next_spline_line_point", -1)
	_check(int(state.get("selected_spline_point_index")) == 2, "previous wraps first tolast")
	state.call("set_spline_line_point_roll_degrees", 1, 810.0)
	var bodies_before := (state.get("material_bodies") as Array).size()
	var preview := state.call("build_spline_roll_preview_body") as Resource
	_check(preview != null and (state.get("material_bodies") as Array).size() == bodies_before,
		"preview uses detached body without publishing material")
	_check(bool(state.call("generate_profile_extrusion_from_spline")), "twisted semantic Handle generates")
	var body := state.call("get_selected_material_body") as Resource
	if _check(body != null, "generated twisted Handle exists"):
		_check(body.get("path_roll_degrees") == PackedFloat64Array([0, 810, 0]), "generated body retains full roll array")
		var layer := state.call("commit_material_body_as_layer", body.get("body_id")) as Resource
		_check(layer != null, "twisted Handle commits as one layer")
	DirAccess.make_dir_recursive_absolute("user://twist_verification")
	var save_path := "user://twist_verification/state.tres"
	_check(ResourceSaver.save(state, save_path) == OK, "state Resource saves")
	var loaded := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if _check(loaded != null, "state Resource reloads"):
		var restored: Dictionary = Adapter.resolve_valid_handle_body(loaded)
		_check(restored.get("valid", false), "reloaded rolled Handle remains valid")
		if restored.get("valid", false):
			_check(restored.body.get("path_roll_degrees") == PackedFloat64Array([0, 810, 0]), "reload preserves810degrees")


func _test_history() -> void:
	var stage: Node = Stage.new()
	root.add_child(stage)
	var state := _state()
	stage.set("active_authoring_state", state)
	_check(bool(stage.call("set_spline_line_point_roll_degrees", 1, 810.0)), "controller roll command")
	_check(bool(stage.call("undo_latest_action")) and _roll_at(state, 1) == 0, "undo restores previous roll")
	_check(bool(stage.call("redo_latest_action")) and _roll_at(state, 1) == 810, "redo restores810degrees")
	stage.call("begin_editor_action_transaction", "Drag twist")
	stage.call("set_spline_line_point_roll_degrees", 1, 900.0)
	stage.call("set_spline_line_point_roll_degrees", 1, 1080.0)
	stage.call("finish_editor_action_transaction")
	_check(bool(stage.call("undo_latest_action")) and _roll_at(state, 1) == 810, "drag is one undo step")
	_check(bool(stage.call("redo_latest_action")) and _roll_at(state, 1) == 1080, "drag redo retains three turns")
	stage.free()


func _body(degrees: float) -> Resource:
	var state := _state()
	state.call("set_spline_line_point_roll_degrees", 1, degrees)
	state.call("generate_profile_extrusion_from_spline")
	var body := state.call("get_selected_material_body") as Resource
	if body != null:
		# Asymmetric and sufficiently wide for all existing target insets.
		body.set("profile_polygon_2d_meters", PackedVector2Array([
			Vector2(-0.025, -0.013), Vector2(0.018, -0.013),
			Vector2(0.018, 0.019), Vector2(-0.025, 0.019)]))
		body.call("normalize")
	return body


func _test_roll_geometry() -> void:
	var body := _body(3600.0)
	if not _check(body != null, "multi-turn geometry fixture"): return
	var curve := Roll.build_body_curve(body, 0.004)
	if not _check(curve != null, "shared sampled curve exists"): return
	var data: Dictionary = curve.get_meta(Roll.FRAME_METADATA)
	var rolls: PackedFloat64Array = data.roll_degrees
	var distances: PackedFloat64Array = data.distances
	var max_step := 0.0
	var max_density := 0.0
	for index: int in range(1, rolls.size()):
		max_step = maxf(max_step, absf(rolls[index] - rolls[index - 1]))
		var distance := distances[index] - distances[index - 1]
		if distance > 0.0000001:
			max_density = maxf(max_density, absf(rolls[index] - rolls[index - 1]) / distance)
	_check(max_step <= 5.0001, "straight multi-turn sweep sampled at most5degrees perstep")
	_check(max_density <= 72000.1, "sampled roll never exceeds5mm-perturn density")
	var peak := Roll.sample_frame(curve, float(data.source_offsets[1]))
	_check(absf(float(peak.roll_degrees) - 3600) < 0.001, "sampled middle retains ten turns")
	evidence["multi_turn"] = {"samples": rolls.size(), "max_step_degrees": max_step,
		"peak_degrees": peak.roll_degrees, "max_density_degrees_per_meter": max_density}
	var zero := body.duplicate(true)
	zero.set("path_roll_degrees", PackedFloat64Array())
	var old_signature := Packet.build_body_signature(zero)
	zero.set("path_roll_degrees", PackedFloat64Array([0, 0, 0]))
	_check(Packet.build_body_signature(zero) == old_signature, "empty andzero arrays retain old signature")
	_check(Packet.build_body_signature(body) != old_signature, "complete turns invalidate old material/target signature")
	var signed_body := _body(90.0)
	var zero_curve := Roll.build_body_curve(zero, 0.004)
	var signed_curve := Roll.build_body_curve(signed_body, 0.004)
	if zero_curve != null and signed_curve != null:
		var base := Roll.sample_frame(zero_curve, 0.05)
		var turned := Roll.sample_frame(signed_curve, 0.05)
		var expected: Vector3 = (base.axis_y as Vector3).rotated(Vector3.RIGHT, -3.0 * PI / 8.0)
		_check((turned.axis_y as Vector3).distance_to(expected) < 0.0001,
			"positive smooth67.5degrees isclockwise viewed downstream towardupstream")
	var curved := _body(90.0)
	curved.set("path_points", PackedVector3Array([Vector3(-0.1, 0, 0), Vector3(0, 0.03, 0), Vector3(0.1, 0, 0)]))
	curved.set("shape_kind", &"shape_kind_spline_profile_path")
	var curved_curve := Roll.build_body_curve(curved, 0.003)
	_check(curved_curve != null, "curved/uneven geometry supports roll sampling")


func _test_smooth_roll_constraints() -> void:
	var points := PackedVector3Array([Vector3.ZERO, Vector3(0.1, 0, 0)])
	_check(Roll.validate_roll_profile(points, PackedFloat64Array([0, 7200]), true).valid, "uniform twist still permits20turns per100mm")
	_check(not Roll.validate_roll_profile(points, PackedFloat64Array([0, 7201]), true).valid, "uniform twist cannot exceed20turns per100mm")
	points.append(Vector3(0.2, 0, 0))
	_check(not Roll.validate_roll_profile(points, PackedFloat64Array([0, 7200, 0]), true).valid, "interior-rate overshoot of a saturated reversal is rejected")
	_check(Roll.validate_roll_profile(points, PackedFloat64Array([0, 3600, 0]), true).valid, "bounded smooth reversal remains available")
	_check(not Roll.validate_roll_profile(points, PackedFloat64Array([-1e308, 1e308, 0]), true).valid, "overflowing finite angle deltas are rejected")
	_check(not Roll.validate_roll_profile(PackedVector3Array([Vector3.ZERO, Vector3.ZERO]), PackedFloat64Array([0, 0]), false).valid, "duplicate spline stations are rejected instead of deduplicating only one authority")
	var body := _body(90.0)
	body.set("path_points", PackedVector3Array([Vector3(-0.1, 0, 0), Vector3.ZERO, Vector3(0.2, 0, 0)]))
	body.set("path_roll_degrees", PackedFloat64Array([0, 90, 300]))
	var curve := Roll.build_body_curve(body, 0.0005)
	var data: Dictionary = curve.get_meta(Roll.FRAME_METADATA)
	var s := float(data.source_offsets[1])
	var left_rate := (float(Roll.sample_frame(curve, s).roll_degrees) - float(Roll.sample_frame(curve, s - 0.0001).roll_degrees)) / 0.0001
	var right_rate := (float(Roll.sample_frame(curve, s + 0.0001).roll_degrees) - float(Roll.sample_frame(curve, s).roll_degrees)) / 0.0001
	_check(absf(left_rate - right_rate) < 5.0, "uneven monotone roll has continuous rate through the interior dot")
	evidence["smooth_roll_knot_rates"] = {"left_degrees_per_m": left_rate, "right_degrees_per_m": right_rate}


func _packet(presenter: Node3D, body: Resource) -> Dictionary:
	var packet: Dictionary = {}
	for _frame: int in range(120):
		packet = presenter.call("_resolve_authoritative_protected_handle_packet", body)
		if not packet.get("pending", false): return packet
		await process_frame
	return packet


func _test_actual_handle_and_wrapper() -> void:
	var presenter: Node3D = Presenter.new()
	root.add_child(presenter)
	var body := _body(90.0)
	var neutral_body := _body(0.0)
	var neutral: Dictionary = await _packet(presenter, neutral_body)
	var packet: Dictionary = await _packet(presenter, body)
	if not _check(neutral.get("ok", false) and packet.get("ok", false), "actual material packets generated: " + str(packet.get("reason", ""))):
		presenter.free(); return
	_check(_closed(packet.primary_grip_handle_vertices, packet.primary_grip_handle_indices), "twisted material mesh isclosed")
	var neutral_slice := _section(neutral.primary_grip_handle_vertices, neutral.primary_grip_handle_indices, -0.05)
	var rolled_slice := _section(packet.primary_grip_handle_vertices, packet.primary_grip_handle_indices, -0.05)
	_check(neutral_slice.size() >= 3 and rolled_slice.size() >= 3, "actual material sections have polygons")
	var max_material_error := _rotated_error(neutral_slice, rolled_slice, -3.0 * PI / 8.0)
	_check(max_material_error < 0.00015, "physical section matches smooth67.5degree roll; error=" + str(max_material_error))
	var config: Dictionary = CONFIG.get("contact_config").duplicate(true)
	var neutral_result: Dictionary = await Baker.new().bake(presenter, neutral_body, neutral, config)
	var result: Dictionary = await Baker.new().bake(presenter, body, packet, config)
	if not _check(neutral_result.get("ok", false) and result.get("ok", false), "real invisible target bake: " + str(result.get("reason", ""))):
		presenter.free(); return
	var wrapper: Resource = result.wrapper
	_check(bool(Validation.validate(wrapper, packet, config).get("valid", false)), "rolled wrapper validates against exact material source")
	var max_target_error := 0.0
	for prefix: String in ["target", "palm_target", "non_thumb_s1_target"]:
		var vertices: PackedVector3Array = wrapper.get(prefix + "_vertices_m")
		var indices: PackedInt32Array = wrapper.get(prefix + "_indices")
		_check(_closed(vertices, indices), prefix + " mesh isclosed")
		var baseline := _section(neutral_result.wrapper.get(prefix + "_vertices_m"), neutral_result.wrapper.get(prefix + "_indices"), -0.05)
		var transformed := _section(vertices, indices, -0.05)
		var error := _rotated_error(baseline, transformed, -3.0 * PI / 8.0)
		max_target_error = maxf(max_target_error, error)
		_check(error < 0.00015, prefix + " uses same smooth67.5degree twist asactual Handle; error=" + str(error))
	var wip: CraftedItemWIP = Wip.new()
	var state := _state()
	state.call("set_spline_line_point_roll_degrees", 1, 90.0)
	state.call("generate_profile_extrusion_from_spline")
	var saved_body := state.call("get_selected_material_body") as Resource
	saved_body.set("profile_polygon_2d_meters", body.get("profile_polygon_2d_meters"))
	saved_body.call("normalize")
	state.call("commit_material_body_as_layer", saved_body.get("body_id"))
	wip.wip_id = &"verify_point_twist"
	wip.forge_builder_path_id = Wip.BUILDER_PATH_MELEE
	wip.forge_builder_component_id = Wip.BUILDER_COMPONENT_PRIMARY
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.forge_v2_authoring_state = state
	var prepared := packet.duplicate(true)
	prepared.primary_grip_target_wrapper = wrapper
	var contract: Dictionary = Adapter.build_runtime_contract(wip, prepared)
	if _check(contract.get("valid", false), "runtime export accepts twisted Handle andtarget: " + str(contract.get("error", ""))):
		wip.stage2_item_state = contract.stage2_item_state
		wip.latest_baked_profile_snapshot = contract.baked_profile
		var save_path := "user://twist_verification/wip.tres"
		_check(ResourceSaver.save(wip, save_path) == OK, "exported WIP saves")
		var loaded := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as CraftedItemWIP
		if _check(loaded != null and loaded.stage2_item_state != null, "exported WIP reloads"):
			var target: Resource = loaded.stage2_item_state.get("primary_grip_target_wrapper")
			_check(target != null and target.get("target_vertices_m") == wrapper.get("target_vertices_m"),
				"saved target vertices survive reload exactly")
	evidence["geometry"] = {"material_triangles": packet.primary_grip_handle_indices.size() / 3,
		"material_section_error_m": max_material_error, "target_section_error_m": max_target_error,
		"target_bake_ms": result.get("build_ms", 0)}
	presenter.free()


func _section(vertices: PackedVector3Array, indices: PackedInt32Array, x: float) -> PackedVector2Array:
	var faces := PackedVector3Array()
	for index: int in indices: faces.append(vertices[index])
	var plane := Transform3D(Basis(Vector3(0, 0, -1), Vector3.UP, Vector3.RIGHT), Vector3(x, 0, 0))
	var helper := Section.new()
	var prepared: Dictionary = helper.prepare({"valid": true, "triangles_world": faces,
		"surface_source_origin_id": &"WeaponRootOrigin", "resolved_world_origin_id": &"RL_BoneRoot"}, plane, &"TwistVerificationPlane")
	var section: Dictionary = helper.slice(prepared, plane)
	return section.get("polygon", PackedVector2Array())


func _rotated_error(before: PackedVector2Array, after: PackedVector2Array, angle: float) -> float:
	if before.size() < 3 or after.size() < 3: return INF
	var maximum := 0.0
	for source: Vector2 in before:
		var point := source.rotated(angle)
		var nearest := INF
		for index: int in after.size():
			nearest = minf(nearest, point.distance_to(Geometry2D.get_closest_point_to_segment(point, after[index], after[(index + 1) % after.size()])))
		maximum = maxf(maximum, nearest)
	return maximum


func _closed(vertices: PackedVector3Array, indices: PackedInt32Array) -> bool:
	var edges: Dictionary = {}
	for triangle: int in range(0, indices.size(), 3):
		for edge: int in 3:
			var a := _point_key(vertices[indices[triangle + edge]])
			var b := _point_key(vertices[indices[triangle + (edge + 1) % 3]])
			var key := a + ":" + b if a < b else b + ":" + a
			edges[key] = int(edges.get(key, 0)) + 1
	for count: int in edges.values():
		if count != 2: return false
	return not edges.is_empty()


func _point_key(point: Vector3) -> String:
	return "%d,%d,%d" % [roundi(point.x * 10000000), roundi(point.y * 10000000), roundi(point.z * 10000000)]


func _check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label)
	return condition
