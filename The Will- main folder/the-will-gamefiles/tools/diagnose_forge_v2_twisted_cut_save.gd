extends SceneTree

## Diagnostic only: real Forge UI/controller/presenter and exact user profile
## templates, isolated output library. No edits to the original profile library.
## -- --out=C:/WORKSPACE/godot_runs/forge_twisted_cut_save/report.json
##    --handle-meters=4.2 --blade-meters=0.09 --turns=30 --skip-cut
const UI = preload("res://scenes/ui_v2/crafting_bench_ui_v2.tscn")
const CONTROLLER = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const LIBRARY = preload("res://core/models/player_forge_wip_library_state.gd")
const PROFILES = preload("res://core/models/player_tool_profile_library_state.gd")
const KEYS = preload("res://runtime/forge_v2/forge_v2_keybinding_state.gd")
const PREFS = preload("res://core/models/forge_v2_editor_settings_state.gd")
const WRAPPER_VALIDATION = preload("res://core/resolvers/prepared_grip_target_wrapper_resolver.gd")
const ADAPTER = preload("res://runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd")
const TEMP_ROOT := "user://tests/forge_twisted_cut_save/"

class FakePlayer extends Node:
	var library: Resource
	func get_forge_wip_library_state() -> Resource:
		return library

class TracedStage extends ForgeV2StageController:
	var trace: Callable
	func build_crafted_item_wip_for_save(
		requested_wip_id: StringName = StringName(),
		requested_project_name: String = "",
		prepared_runtime_mesh_packet: Dictionary = {}
	) -> CraftedItemWIP:
		trace.call("wip_build_begin", {})
		var began := Time.get_ticks_usec()
		var wip := super.build_crafted_item_wip_for_save(
			requested_wip_id, requested_project_name, prepared_runtime_mesh_packet
		)
		trace.call("wip_build_end", {"ok": wip != null,
			"duration_ms": float(Time.get_ticks_usec() - began) / 1000.0})
		return wip

var controller: Node
var ui: CanvasLayer
var state: Resource
var presenter: Node3D
var library: Resource
var source_mesh_provider := Callable()
var source_wrapper_provider := Callable()
var report_path := "C:/WORKSPACE/godot_runs/forge_twisted_cut_save/report.json"
var events: Array[Dictionary] = []
var phase := "startup"
var began_usec := 0
var last_frame_usec := 0
var max_frame_gap_ms := 0.0
var phase_max_gap_ms := 0.0
var frames := 0
var handle_meters := 4.2
var blade_meters := 0.09
var turns := 30.0
var skip_cut := false
var pointed_blade := false
var save_started_usec := 0
var last_save_text := ""
var export_call_count := 0
var final_export_packet: Dictionary = {}
var blade_volume_before_cut := 0.0
var blade_volume_after_cut := 0.0

func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): report_path = argument.trim_prefix("--out=")
		elif argument.begins_with("--handle-meters="): handle_meters = float(argument.trim_prefix("--handle-meters="))
		elif argument.begins_with("--blade-meters="): blade_meters = float(argument.trim_prefix("--blade-meters="))
		elif argument.begins_with("--turns="): turns = float(argument.trim_prefix("--turns="))
		elif argument == "--skip-cut": skip_cut = true
		elif argument == "--pointed-blade": pointed_blade = true
	began_usec = Time.get_ticks_usec()
	last_frame_usec = began_usec
	process_frame.connect(_observe_frame)
	call_deferred("_run")

func _observe_frame() -> void:
	var now := Time.get_ticks_usec()
	var gap_ms := float(now - last_frame_usec) / 1000.0
	max_frame_gap_ms = maxf(max_frame_gap_ms, gap_ms)
	phase_max_gap_ms = maxf(phase_max_gap_ms, gap_ms)
	last_frame_usec = now
	frames += 1
	if ui != null and bool(ui.get("v2_save_in_progress")):
		var label := ui.get("v2_save_progress_label") as Label
		if label != null and label.text != last_save_text:
			last_save_text = label.text
			_record("save_progress", {"text": label.text})

func _run() -> void:
	_record("fixture", {"handle_meters": handle_meters, "blade_meters": blade_meters,
		"turns": turns, "skip_cut": skip_cut,
		"assumption": "Straight X-axis two-dot Handle; 70% of 6m workspace; blade5%remainingwidth; diagonal box notch at blade tip."})
	var source_profiles := ResourceLoader.load(PROFILES.DEFAULT_SAVE_FILE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Resource
	if source_profiles == null:
		_finish(false, "real_profile_library_not_found")
		return
	var handle_profile := _find_profile(source_profiles, "Medoum rounded")
	var blade_profile := _find_profile(source_profiles, "fluted blade")
	var box_profile := _find_profile(source_profiles, "box1")
	if handle_profile.is_empty() or blade_profile.is_empty() or box_profile.is_empty():
		_finish(false, "named_template_missing")
		return
	library = LIBRARY.new()
	library.set("save_file_path", TEMP_ROOT + "wips.tres")
	var fake_player := FakePlayer.new()
	fake_player.library = library
	root.add_child(fake_player)
	controller = TracedStage.new()
	controller.set("trace", Callable(self, "_record"))
	var prefs := PREFS.new()
	prefs.save_file_path = TEMP_ROOT + "preferences.tres"
	controller.set("editor_settings", prefs)
	root.add_child(controller)
	ui = UI.instantiate()
	var isolated_profiles := source_profiles.duplicate(true)
	isolated_profiles.set("save_file_path", TEMP_ROOT + "profiles.tres")
	ui.set("tool_profile_library_state", isolated_profiles)
	var isolated_keys := KEYS.new()
	isolated_keys.save_file_path = TEMP_ROOT + "keys.json"
	ui.set("keybinding_state", isolated_keys)
	root.add_child(ui)
	await process_frame
	ui.call("open_for", fake_player, controller, "Twisted cut Save diagnostic")
	await process_frame
	await physics_frame
	state = controller.call("get_active_authoring_state") as Resource
	var workspace := ui.get("workspace_preview") as Node3D
	presenter = workspace.get("volume_preview_presenter") as Node3D
	var contract: Resource = controller.call("ensure_workspace_contract")
	_record("workspace", {"bounds_min": contract.get("local_min"), "bounds_max": contract.get("local_max")})
	var start_x := -handle_meters * 0.5
	var end_x := start_x + handle_meters

	_set_phase("handle_authoring")
	controller.call("select_tool_for_authoring", &"tool_handles")
	controller.call("set_active_handle_path_mode_id", &"handle_path_2_point_linear")
	if not bool(controller.call("apply_tool_profile_preset", handle_profile)):
		_finish(false, "handle_profile_rejected")
		return
	controller.call("append_spline_line_point", Vector3(start_x, 0, 0), Vector3.UP)
	controller.call("append_spline_line_point", Vector3(end_x, 0, 0), Vector3.UP)
	controller.call("set_spline_line_point_roll_degrees", 1, turns * 360.0)
	_record("handle_roll", {"roll_degrees": state.get("spline_line_roll_degrees")})
	if not await _generate_and_commit("generate_profile_extrusion_from_spline"):
		return

	_set_phase("blade_authoring")
	controller.call("select_tool_for_authoring", &"tool_spline_line")
	controller.call("set_active_operation_mode", &"operation_add_material")
	if not bool(controller.call("select_active_saved_basic_profile", blade_profile)):
		_finish(false, "blade_profile_rejected")
		return
	controller.call("append_spline_line_point", Vector3(end_x - 0.01, 0, 0), Vector3.UP)
	controller.call("append_spline_line_point", Vector3(end_x + blade_meters, 0, 0), Vector3.UP)
	if pointed_blade:
		controller.call("set_spline_line_point_profile_scale", 1, Vector2.ZERO)
	if not await _generate_and_commit("generate_spline_line_csg_noodle"):
		return
	blade_volume_before_cut = _ordinary_volume()
	var blade_body := state.call("get_selected_material_body") as Resource
	var blade_packet: Dictionary = presenter.call("_build_native_static_operand_packet", blade_body)
	var blade_bounds := _packet_bounds(blade_packet)
	_record("blade_before_cut", {"volume_m3": blade_volume_before_cut, "bounds": blade_bounds,
		"profile_id": blade_body.get("profile_id"), "shape_kind": blade_body.get("shape_kind")})

	if not skip_cut:
		_set_phase("box_removal")
		controller.call("select_tool_for_authoring", &"tool_spline_line")
		controller.call("set_active_operation_mode", &"operation_remove_material")
		if not bool(controller.call("select_active_saved_basic_profile", box_profile)):
			_finish(false, "box_profile_rejected")
			return
		# Exact saved box profile, crossing the last blade corner diagonally.
		# This authors a Remove operand through the same spline/controller path.
		var cutter_points := PackedVector3Array([Vector3(-0.04, 0, -0.1), Vector3(0.04, 0, 0.1)])
		for point: Vector3 in cutter_points:
			controller.call("append_spline_line_point", point, Vector3.UP)
		# Locate the actual deposited cutter after the profile's contact-anchor
		# offset, then position it via control points. This avoids guessing that
		# the drawn path is the centre of the saved shape.
		var preview_body := state.call("build_spline_roll_preview_body") as Resource
		var preview_packet: Dictionary = presenter.call("_build_native_static_operand_packet", preview_body)
		var cutter_bounds := _packet_bounds(preview_packet)
		var desired_center := Vector3(
			blade_bounds.end.x + cutter_bounds.size.x * 0.5 - minf(0.035, blade_meters * 0.4),
			blade_bounds.get_center().y,
			blade_bounds.get_center().z)
		var cutter_offset := desired_center - cutter_bounds.get_center()
		for index in range(cutter_points.size()):
			controller.call("set_spline_line_point", index, cutter_points[index] + cutter_offset)
		_record("box_placement", {"initial_bounds": cutter_bounds, "offset": cutter_offset})
		if not await _generate_and_commit("generate_spline_line_csg_noodle"):
			return
		blade_volume_after_cut = _ordinary_volume()
		var cut_reduced_volume := blade_volume_after_cut > 0.0 and blade_volume_after_cut < blade_volume_before_cut * 0.99999
		_record("box_cut_volume", {"before_m3": blade_volume_before_cut, "after_m3": blade_volume_after_cut, "reduced": cut_reduced_volume})
		if not cut_reduced_volume:
			_finish(false, "diagnostic_cutter_did_not_reduce_blade")
			return

	_set_phase("save")
	source_mesh_provider = state.get("_runtime_contract_mesh_export_provider")
	source_wrapper_provider = controller.get("_grip_target_wrapper_export_provider")
	state.call("set_runtime_contract_mesh_export_provider", Callable(self, "_timed_mesh_export"))
	controller.call("set_grip_target_wrapper_export_provider", Callable(self, "_timed_wrapper_export"))
	save_started_usec = Time.get_ticks_usec()
	_record("save_requested")
	# Exact command reached by Ctrl+S; it uses the production preparation and persist transaction.
	if not bool(ui.call("_save_current_v2_draft")):
		_finish(false, "save_request_rejected")
		return
	while bool(ui.get("v2_save_in_progress")):
		await process_frame
		if Time.get_ticks_usec() - save_started_usec > 180000000:
			_finish(false, "save_did_not_settle_180s")
			return
	var status := ui.get("action_status_label") as Label
	var saved_count := (library.get("saved_wips") as Array).size()
	_record("save_finished", {"duration_ms": float(Time.get_ticks_usec() - save_started_usec) / 1000.0,
		"status": status.text if status != null else "", "saved_count": saved_count})
	var reloaded := _verify_disk_reload() if saved_count == 1 else false
	_finish(saved_count == 1 and reloaded, "saved_and_reloaded" if reloaded else "save_or_reload_failed")

func _ordinary_volume() -> float:
	var backend: Object = presenter.get("native_static_manifold_backend")
	return float((backend.call("get_state_info") as Dictionary).get("state_volume_m3", -1.0)) if backend != null else -1.0

func _packet_bounds(packet: Dictionary) -> AABB:
	var vertices: PackedVector3Array = packet.get("vertices", PackedVector3Array())
	if vertices.is_empty(): return AABB()
	var bounds := AABB(vertices[0], Vector3.ZERO)
	for vertex: Vector3 in vertices:
		bounds = bounds.expand(vertex)
	return bounds

func _verify_disk_reload() -> bool:
	_set_phase("disk_reload")
	_record("disk_reload_begin", {"path": library.get("save_file_path")})
	var disk := ResourceLoader.load(String(library.get("save_file_path")), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as Resource
	if disk == null or (disk.get("saved_wips") as Array).size() != 1:
		_record("disk_reload_end", {"ok": false, "reason": "saved_library_missing"})
		return false
	var wip: Resource = (disk.get("saved_wips") as Array)[0]
	var stage2 := wip.get("stage2_item_state") as Resource
	var handle_result: Dictionary = ADAPTER.resolve_valid_handle_body(wip.get("forge_v2_authoring_state"))
	if stage2 == null or not bool(handle_result.get("valid", false)):
		_record("disk_reload_end", {"ok": false, "reason": "stage2_or_handle_missing"})
		return false
	var handle: Resource = handle_result.body
	var rolls: PackedFloat64Array = handle.get("path_roll_degrees")
	var handle_ok := rolls.size() == 2 and is_equal_approx(rolls[1], turns * 360.0)
	var wrapper := stage2.get("primary_grip_target_wrapper") as Resource
	var wrapper_check: Dictionary = WRAPPER_VALIDATION.validate(wrapper, final_export_packet)
	var mesh := stage2.get("current_editable_mesh_state") as Resource
	var arrays: Array = mesh.get("surface_arrays") if mesh != null else []
	var geometry_ok := arrays.size() == Mesh.ARRAY_MAX
	var max_error_m := 0.0
	if geometry_ok:
		var source_vertices: PackedVector3Array = final_export_packet.get("vertices", PackedVector3Array())
		var saved_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		geometry_ok = saved_vertices.size() == source_vertices.size() and arrays[Mesh.ARRAY_INDEX] == final_export_packet.get("indices")
		if geometry_ok:
			var cell_m := float(stage2.get("cell_world_size_meters"))
			for index in range(saved_vertices.size()):
				max_error_m = maxf(max_error_m, (saved_vertices[index] * cell_m).distance_to(source_vertices[index]))
			geometry_ok = max_error_m < 0.00001
	var taper_ok := not pointed_blade
	if pointed_blade:
		for body: Resource in (wip.get("forge_v2_authoring_state") as Resource).get("material_bodies"):
			var scales: PackedVector2Array = body.get("path_profile_scales")
			if not scales.is_empty() and scales[-1] == Vector2.ZERO:
				taper_ok = true
	var ok := handle_ok and bool(wrapper_check.get("valid", false)) and geometry_ok and taper_ok
	_record("disk_reload_end", {"ok": ok, "handle_roll_preserved": handle_ok,
		"pointed_blade": pointed_blade, "taper_preserved": taper_ok,
		"wrapper_valid": wrapper_check, "cut_mesh_preserved": geometry_ok,
		"max_geometry_error_m": max_error_m, "saved_name": wip.get("forge_project_name")})
	return ok

func _find_profile(source: Resource, label: String) -> Dictionary:
	for profile: Dictionary in source.get("saved_profiles"):
		if String(profile.get("label", "")).nocasecmp_to(label) == 0:
			_record("profile", {"label": label, "polygon_points": (profile.get("polygon_2d_meters", PackedVector2Array()) as PackedVector2Array).size(),
				"width_meters": profile.get("width_meters"), "height_meters": profile.get("height_meters")})
			return profile.duplicate(true)
	return {}

func _generate_and_commit(method: String) -> bool:
	_record("generate_begin", {"method": method})
	var began := Time.get_ticks_usec()
	var generated := bool(controller.call(method))
	_record("generate_end", {"ok": generated, "duration_ms": float(Time.get_ticks_usec() - began) / 1000.0})
	if not generated:
		_record("generation_diagnostics", {
			"spline": state.call("get_spline_line_summary"),
			"profile": state.call("get_active_profile_settings_summary"),
			"handle_status": state.call("get_profile_extrusion_status_label"),
			"roll_status": state.call("get_spline_line_roll_status"),
			"path_mode": state.get("active_handle_path_mode_id"),
			"point_count": (state.get("spline_line_points") as PackedVector3Array).size(),
		})
		_finish(false, "generate_failed:" + method)
		return false
	_record("commit_begin")
	began = Time.get_ticks_usec()
	var committed: Dictionary = await controller.call("commit_all_pending_material_bodies_as_layers", 30000)
	_record("commit_end", {"result": committed, "duration_ms": float(Time.get_ticks_usec() - began) / 1000.0})
	if not bool(committed.get("ok", false)):
		_finish(false, "commit_failed")
		return false
	return await _settle_geometry()

func _settle_geometry() -> bool:
	_record("geometry_settle_begin")
	var began := Time.get_ticks_usec()
	var settled_frames := 0
	while Time.get_ticks_usec() - began < 60000000:
		await process_frame
		await physics_frame
		if bool(presenter.get("native_static_publication_pending")) or bool(state.call("has_pending_bounded_history_promotion")):
			settled_frames = 0
			continue
		settled_frames += 1
		if settled_frames < 12:
			continue
		# Export readiness is the production authority. Do not equate a frame
		# count alone with an already-cooked protected Handle/Boolean result.
		_record("geometry_readiness_export_begin")
		var packet: Dictionary = state.call("request_runtime_contract_mesh_export")
		_record("geometry_readiness_export_end", _packet_summary(packet))
		if bool(packet.get("ok", false)):
			_record("geometry_settled", {"duration_ms": float(Time.get_ticks_usec() - began) / 1000.0,
				"native_diagnostics": presenter.get("native_static_sync_diagnostics")})
			return true
		if not bool(packet.get("pending", false)):
			_finish(false, "geometry_export_failed:" + String(packet.get("error_code", "unknown")))
			return false
		settled_frames = 0
	_finish(false, "geometry_settle_timeout")
	return false

func _timed_mesh_export() -> Dictionary:
	export_call_count += 1
	_record("save_mesh_export_begin", {"call": export_call_count})
	var began := Time.get_ticks_usec()
	var packet: Dictionary = source_mesh_provider.call()
	if bool(packet.get("ok", false)):
		final_export_packet = packet
	var summary := _packet_summary(packet)
	summary["duration_ms"] = float(Time.get_ticks_usec() - began) / 1000.0
	_record("save_mesh_export_end", summary)
	return packet

func _timed_wrapper_export(body: Resource, packet: Dictionary, config: Dictionary) -> Dictionary:
	_record("wrapper_begin", _packet_summary(packet))
	var began := Time.get_ticks_usec()
	var result: Dictionary = await source_wrapper_provider.call(body, packet, config)
	_record("wrapper_end", {"ok": result.get("ok", false), "reason": result.get("reason", ""),
		"duration_ms": float(Time.get_ticks_usec() - began) / 1000.0})
	return result

func _packet_summary(packet: Dictionary) -> Dictionary:
	return {"ok": packet.get("ok", false), "pending": packet.get("pending", false),
		"error_code": packet.get("error_code", ""), "reason": packet.get("reason", ""),
		"vertices": (packet.get("vertices", PackedVector3Array()) as PackedVector3Array).size(),
		"triangles": (packet.get("indices", PackedInt32Array()) as PackedInt32Array).size() / 3}

func _set_phase(value: String) -> void:
	_record("phase_end", {"phase_max_frame_gap_ms": phase_max_gap_ms})
	phase = value
	phase_max_gap_ms = 0.0
	_record("phase_begin")

func _record(event: String, data: Dictionary = {}) -> void:
	var row := data.duplicate(true)
	row["event"] = event
	row["phase"] = phase
	row["elapsed_ms"] = float(Time.get_ticks_usec() - began_usec) / 1000.0
	row["frames"] = frames
	row["max_frame_gap_ms"] = max_frame_gap_ms
	events.append(row)
	print("TWISTED_CUT_SAVE ", JSON.stringify(row))
	_write_report()

func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"events": events, "max_frame_gap_ms": max_frame_gap_ms}, "\t"))
		file.flush()

func _finish(ok: bool, reason: String) -> void:
	_record("finished", {"ok": ok, "reason": reason})
	quit(0 if ok else 1)
