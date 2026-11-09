extends SceneTree

## Creates the user-requested melee fixture in the REAL player WIP library.
## Production authoring/controller, Generate, commit and UI Save As are used.
## Existing weapons are retained; a duplicate fixture name is never overwritten.
## Run only after the point-transform geometry checks have passed.
## -- --out=C:/WORKSPACE/godot_runs/forge_v2_taper_test/report.json
const UI = preload("res://scenes/ui_v2/crafting_bench_ui_v2.tscn")
const CONTROLLER = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const LIBRARY = preload("res://core/models/player_forge_wip_library_state.gd")
const PROFILES = preload("res://core/models/player_tool_profile_library_state.gd")
const KEYS = preload("res://runtime/forge_v2/forge_v2_keybinding_state.gd")
const PREFS = preload("res://core/models/forge_v2_editor_settings_state.gd")
const WIP = preload("res://core/models/crafted_item_wip.gd")
const BODY = preload("res://runtime/forge_v2/forge_v2_material_body.gd")
const ADAPTER = preload("res://runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd")
const WRAPPER_VALIDATION = preload("res://core/resolvers/prepared_grip_target_wrapper_resolver.gd")
const FIXTURE_NAME := "Taper_test"
const TEMP_ROOT := "user://tests/forge_v2_taper_test/"
const HANDLE_LENGTH_M := 0.15
const POINT_SPACING_M := 0.15
const BLADE_POINT_COUNT := 5

class FixturePlayer extends Node:
	var library: Resource
	func get_forge_wip_library_state() -> Resource:
		return library

var controller: Node
var ui: CanvasLayer
var state: Resource
var presenter: Node3D
var library: Resource
var original_wips: Array = []
var original_unarmed: Resource
var original_handle: Resource
var expected_blade_points := PackedVector3Array()
var final_export_packet: Dictionary = {}
var source_mesh_provider := Callable()
var report_path := "C:/WORKSPACE/godot_runs/forge_v2_taper_test/report.json"
var events: Array[Dictionary] = []
var began_usec := 0
var saved_wip_id := StringName()
var preservation_difference := ""

func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			report_path = argument.trim_prefix("--out=")
	began_usec = Time.get_ticks_usec()
	call_deferred("_run")

func _run() -> void:
	_record("fixture_requested", {"name": FIXTURE_NAME,
		"handle_length_m": HANDLE_LENGTH_M, "blade_points": BLADE_POINT_COUNT,
		"blade_spacing_m": POINT_SPACING_M,
		"diamond_roles_zero_based": [0, 1, 2], "diamond_scale": [2.0, 2.0],
		"first_cone_roles_zero_based": [3, 2], "first_cone_scale": [2.0, 2.0],
		"second_cone_roles_zero_based": [4, 3], "second_cone_scale": [2.0, 2.0],
		"base_scales": [0.05, 0.05, 0.05, 0.05, 0.0]})
	library = ResourceLoader.load(LIBRARY.DEFAULT_SAVE_FILE_PATH, "",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP) as Resource
	var source_profiles := ResourceLoader.load(PROFILES.DEFAULT_SAVE_FILE_PATH, "",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP) as Resource
	if library == null or source_profiles == null:
		_finish(false, "real_library_or_profiles_missing")
		return
	# Do not call load_or_create: a missing real library must not become an empty
	# replacement. Save uses its real standard path, regardless of stale metadata.
	library.set("save_file_path", LIBRARY.DEFAULT_SAVE_FILE_PATH)
	original_wips = (library.get("saved_wips") as Array).duplicate()
	original_unarmed = library.get("unarmed_authoring_wip") as Resource
	for existing: Resource in original_wips:
		if existing == null or not (
			WIP.is_forge_v2_authoring_wip(existing as CraftedItemWIP)
			or WIP.is_unarmed_authoring_wip(existing as CraftedItemWIP)
		):
			# Production save prunes retired records. Do not run a fixture save if
			# doing so could remove any existing record from this particular library.
			_finish(false, "existing_library_contains_retired_record")
			return
		if String(existing.get("forge_project_name")) == FIXTURE_NAME:
			_finish(false, "taper_test_already_exists")
			return
	var handle_profile := _find_profile(source_profiles, "Medoum rounded")
	var blade_profile := _find_profile(source_profiles, "fluted blade")
	if handle_profile.is_empty() or blade_profile.is_empty():
		_finish(false, "real_medium_round_or_fluted_profile_missing")
		return
	var player := FixturePlayer.new()
	player.library = library
	root.add_child(player)
	controller = CONTROLLER.new()
	var preferences := PREFS.new()
	preferences.save_file_path = TEMP_ROOT + "preferences.tres"
	controller.set("editor_settings", preferences)
	root.add_child(controller)
	ui = UI.instantiate()
	var private_profiles := source_profiles.duplicate(true)
	private_profiles.set("save_file_path", TEMP_ROOT + "profiles.tres")
	ui.set("tool_profile_library_state", private_profiles)
	var private_keys := KEYS.new()
	private_keys.save_file_path = TEMP_ROOT + "keys.json"
	ui.set("keybinding_state", private_keys)
	root.add_child(ui)
	await process_frame
	ui.call("open_for", player, controller, FIXTURE_NAME)
	controller.call("set_builder_path_id", WIP.BUILDER_PATH_MELEE)
	controller.call("set_builder_component_id", WIP.BUILDER_COMPONENT_PRIMARY)
	await process_frame
	await physics_frame
	state = controller.call("get_active_authoring_state") as Resource
	var workspace := ui.get("workspace_preview") as Node3D
	presenter = workspace.get("volume_preview_presenter") as Node3D
	if state == null or presenter == null:
		_finish(false, "forge_workspace_unavailable")
		return
	var workspace_contract: Resource = controller.call("ensure_workspace_contract")
	_record("workspace", {"bounds_min": workspace_contract.get("local_min"),
		"bounds_max": workspace_contract.get("local_max"),
		"existing_weapons": original_wips.size()})

	controller.call("select_tool_for_authoring", &"tool_handles")
	controller.call("set_active_handle_path_mode_id", &"handle_path_2_point_linear")
	if not bool(controller.call("apply_tool_profile_preset", handle_profile)):
		_finish(false, "medium_round_handle_profile_rejected")
		return
	# The unchanged 15 cm Handle extends 2 cm past A. The first blade section
	# remains 5% under the Handle, so this is real overlap rather than point contact.
	if not _append_point(Vector3(0.02 - HANDLE_LENGTH_M, 0, 0), 0): return
	if not _append_point(Vector3(0.02, 0, 0), 1): return
	if not await _generate_and_commit("generate_profile_extrusion_from_spline"): return
	var handle_result: Dictionary = ADAPTER.resolve_valid_handle_body(state)
	if not bool(handle_result.get("valid", false)):
		_finish(false, "generated_handle_invalid")
		return
	original_handle = (handle_result.get("body") as Resource).duplicate(true)
	# Compare like-for-like saved resources. Godot's text resource writer
	# rounds e.g. 0.012500000186264515 to 0.0125; this is not a Handle edit.
	var expected_handle_path := TEMP_ROOT + "expected_handle_before_save.tres"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))
	if ResourceSaver.save(original_handle, expected_handle_path) != OK:
		_finish(false, "expected_handle_roundtrip_failed")
		return
	original_handle = ResourceLoader.load(expected_handle_path, "",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP) as Resource
	if original_handle == null:
		_finish(false, "expected_handle_roundtrip_reload_failed")
		return

	controller.call("select_tool_for_authoring", &"tool_spline_line")
	controller.call("set_active_operation_mode", &"operation_add_material")
	if not bool(controller.call("select_active_saved_basic_profile", blade_profile)):
		_finish(false, "fluted_blade_profile_rejected")
		return
	for index in range(BLADE_POINT_COUNT):
		var point := Vector3(float(index) * POINT_SPACING_M, 0, 0)
		expected_blade_points.append(point)
		if not _append_point(point, index): return
	for index in range(BLADE_POINT_COUNT):
		var base_scale := Vector2.ZERO if index == BLADE_POINT_COUNT - 1 else Vector2(0.05, 0.05)
		if not bool(controller.call("set_spline_line_point_profile_scale", index, base_scale)):
			_finish(false, "base_scale_rejected")
			return
	for specification: Dictionary in [
		{"roles": PackedInt32Array([0, 1, 2]), "scale": Vector2(2.0, 2.0)},
		{"roles": PackedInt32Array([3, 2]), "scale": Vector2(2.0, 2.0)},
		{"roles": PackedInt32Array([4, 3]), "scale": Vector2(2.0, 2.0)},
	]:
		if not bool(controller.call("set_spline_line_profile_transform",
			specification.roles, specification.scale)):
			_finish(false, "range_transform_rejected")
			return
	_record("authored_ranges", {"ranges": state.get("spline_line_profile_transform_ranges")})
	if not await _generate_and_commit("generate_spline_line_csg_noodle"): return
	if not _backup_real_library(): return

	source_mesh_provider = state.get("_runtime_contract_mesh_export_provider")
	state.call("set_runtime_contract_mesh_export_provider", Callable(self, "_capture_mesh_export"))
	var save_started_usec := Time.get_ticks_usec()
	# Same production transaction as Draft -> Save As; no direct .tres creation
	# and no fixture-only export/persistence bypass.
	if not bool(ui.call("_save_current_v2_draft_as", FIXTURE_NAME)):
		_finish(false, "production_save_as_rejected")
		return
	while bool(ui.get("v2_save_in_progress")):
		await process_frame
		if Time.get_ticks_usec() - save_started_usec > 180000000:
			_finish(false, "save_timeout_180s")
			return
	saved_wip_id = StringName(controller.call("get_active_saved_wip_id"))
	var status := ui.get("action_status_label") as Label
	_record("save_finished", {"duration_ms": float(Time.get_ticks_usec() - save_started_usec) / 1000.0,
		"status": status.text if status != null else "", "wip_id": saved_wip_id})
	var verified := _verify_disk_reload()
	_finish(verified, "real_taper_test_saved_and_reloaded" if verified else "cold_reload_validation_failed")

func _append_point(point: Vector3, expected_index: int) -> bool:
	var actual_index := int(controller.call("append_spline_line_point", point, Vector3.UP))
	if actual_index != expected_index:
		_finish(false, "point_append_rejected:%d" % expected_index)
		return false
	return true

func _generate_and_commit(method: String) -> bool:
	_record("generate_begin", {"method": method})
	if not bool(controller.call(method)):
		_record("generation_status", {"spline": state.call("get_spline_line_summary"),
			"handle": state.call("get_profile_extrusion_status_label")})
		_finish(false, "generation_failed:" + method)
		return false
	var committed: Dictionary = await controller.call("commit_all_pending_material_bodies_as_layers", 30000)
	_record("commit_finished", {"method": method, "result": committed})
	if not bool(committed.get("ok", false)):
		_finish(false, "layer_commit_failed")
		return false
	var began := Time.get_ticks_usec()
	var settled_frames := 0
	while Time.get_ticks_usec() - began < 60000000:
		await process_frame
		await physics_frame
		if bool(presenter.get("native_static_publication_pending")) or bool(state.call("has_pending_bounded_history_promotion")):
			settled_frames = 0
			continue
		settled_frames += 1
		if settled_frames < 12: continue
		var packet: Dictionary = state.call("request_runtime_contract_mesh_export")
		if bool(packet.get("ok", false)):
			final_export_packet = packet
			_record("geometry_ready", {"method": method,
				"vertices": (packet.get("vertices", PackedVector3Array()) as PackedVector3Array).size(),
				"triangles": (packet.get("indices", PackedInt32Array()) as PackedInt32Array).size() / 3})
			return true
		if not bool(packet.get("pending", false)):
			_finish(false, "mesh_export_failed:" + String(packet.get("error_code", "unknown")))
			return false
		settled_frames = 0
	_finish(false, "geometry_settle_timeout_60s")
	return false

func _backup_real_library() -> bool:
	var backup := report_path.get_base_dir().path_join("player_wip_library_before_taper_test_%d.tres" % int(Time.get_unix_time_from_system()))
	DirAccess.make_dir_recursive_absolute(backup.get_base_dir())
	var error := DirAccess.copy_absolute(ProjectSettings.globalize_path(LIBRARY.DEFAULT_SAVE_FILE_PATH), backup)
	_record("library_backup", {"path": backup, "error": error})
	if error != OK:
		_finish(false, "library_backup_failed")
		return false
	return true

func _capture_mesh_export() -> Dictionary:
	var packet: Dictionary = source_mesh_provider.call()
	if bool(packet.get("ok", false)):
		final_export_packet = packet
	return packet

func _verify_disk_reload() -> bool:
	var disk := ResourceLoader.load(LIBRARY.DEFAULT_SAVE_FILE_PATH, "",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP) as Resource
	if disk == null or saved_wip_id == StringName():
		_record("cold_reload", {"ok": false, "reason": "saved_library_or_id_missing"})
		return false
	var saved: Resource = disk.call("get_saved_wip", saved_wip_id)
	var all_saved: Array = disk.get("saved_wips")
	var preserved := all_saved.size() == original_wips.size() + 1
	for original: Resource in original_wips:
		var corresponding: Resource = disk.call("get_saved_wip", StringName(original.get("wip_id")))
		preserved = _same_stored_value(original, corresponding, {}, String(original.get("wip_id"))) and preserved
	preserved = _same_stored_value(original_unarmed, disk.get("unarmed_authoring_wip"), {}, "unarmed") and preserved
	if saved == null:
		_record("cold_reload", {"ok": false, "reason": "saved_fixture_missing", "other_weapons_preserved": preserved})
		return false
	var saved_state := saved.get("forge_v2_authoring_state") as Resource
	var stage2 := saved.get("stage2_item_state") as Resource
	var identity_ok := String(saved.get("forge_project_name")) == FIXTURE_NAME and StringName(saved.get("forge_builder_path_id")) == WIP.BUILDER_PATH_MELEE
	var handle_result: Dictionary = ADAPTER.resolve_valid_handle_body(saved_state)
	var handle_ok := bool(handle_result.get("valid", false)) and _same_stored_value(original_handle, handle_result.get("body"), {}, "handle")
	var blade: Resource
	if saved_state != null:
		for body: Resource in saved_state.get("material_bodies"):
			if StringName(body.get("body_kind")) != BODY.BODY_KIND_HANDLE_PROFILE and (body.get("path_points") as PackedVector3Array).size() == BLADE_POINT_COUNT:
				blade = body
	var ranges_ok := _verify_blade_ranges(blade)
	var handle_artifacts_ok := _save_body_artifacts("handle", handle_result.get("body") as Resource)
	var blade_artifacts_ok := _save_body_artifacts("blade", blade)
	var geometry_ok := false
	var max_error_m := 0.0
	var wrapper_result: Dictionary = {}
	if stage2 != null:
		wrapper_result = WRAPPER_VALIDATION.validate(stage2.get("primary_grip_target_wrapper"), final_export_packet)
		var mesh := stage2.get("current_editable_mesh_state") as Resource
		var arrays: Array = mesh.get("surface_arrays") if mesh != null else []
		geometry_ok = arrays.size() == Mesh.ARRAY_MAX
		if geometry_ok:
			var source_vertices: PackedVector3Array = final_export_packet.get("vertices", PackedVector3Array())
			var saved_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			geometry_ok = not source_vertices.is_empty() and saved_vertices.size() == source_vertices.size() and arrays[Mesh.ARRAY_INDEX] == final_export_packet.get("indices")
			if geometry_ok:
				var cell_m := float(stage2.get("cell_world_size_meters"))
				for index in range(saved_vertices.size()):
					max_error_m = maxf(max_error_m, (saved_vertices[index] * cell_m).distance_to(source_vertices[index]))
				geometry_ok = max_error_m < 0.00001
	var ok := identity_ok and preserved and handle_ok and ranges_ok and geometry_ok and bool(wrapper_result.get("valid", false)) and handle_artifacts_ok and blade_artifacts_ok
	_record("cold_reload", {"ok": ok, "name_and_melee": identity_ok,
		"other_weapons_preserved": preserved, "preservation_difference": preservation_difference,
		"unchanged_handle": handle_ok, "blade_points_and_ranges": ranges_ok,
		"render_artifacts_saved": handle_artifacts_ok and blade_artifacts_ok,
		"mesh_matches_production_export": geometry_ok, "max_mesh_error_m": max_error_m,
		"wrapper": wrapper_result, "wip_id": saved_wip_id})
	return ok

func _save_body_artifacts(label: String, body: Resource) -> bool:
	if body == null: return false
	var mesh := presenter.call("_build_active_material_body_sweep_mesh", body) as ArrayMesh
	if mesh == null or mesh.get_surface_count() == 0:
		_record("body_artifacts", {"label": label, "ok": false, "reason": "production_sweep_empty"})
		return false
	var body_path := report_path.get_base_dir().path_join(label + "_body.tres")
	var mesh_path := report_path.get_base_dir().path_join(label + "_mesh.res")
	var body_error := ResourceSaver.save(body.duplicate(true), body_path)
	var mesh_error := ResourceSaver.save(mesh, mesh_path)
	var ok := body_error == OK and mesh_error == OK
	_record("body_artifacts", {"label": label, "ok": ok,
		"body_path": body_path, "mesh_path": mesh_path,
		"body_error": body_error, "mesh_error": mesh_error})
	return ok

func _verify_blade_ranges(blade: Resource) -> bool:
	if blade == null: return false
	var points: PackedVector3Array = blade.get("path_points")
	if points.size() != expected_blade_points.size(): return false
	for index in range(points.size()):
		if not points[index].is_equal_approx(expected_blade_points[index]): return false
	var base_scales: PackedVector2Array = blade.get("path_profile_scales")
	if base_scales.size() != BLADE_POINT_COUNT: return false
	for index in range(base_scales.size()):
		var expected_scale := Vector2.ZERO if index == BLADE_POINT_COUNT - 1 else Vector2(0.05, 0.05)
		if not base_scales[index].is_equal_approx(expected_scale): return false
	var ranges: Array = blade.get("path_profile_transform_ranges")
	if ranges.size() != 3: return false
	var expected: Array[Dictionary] = [
		{"fixed_a": 0, "scaled": 1, "fixed_b": 2, "scale": Vector2(2.0, 2.0)},
		{"fixed_a": 3, "scaled": 2, "fixed_b": -1, "scale": Vector2(2.0, 2.0)},
		{"fixed_a": 4, "scaled": 3, "fixed_b": -1, "scale": Vector2(2.0, 2.0)},
	]
	for index in range(expected.size()):
		for key: String in ["fixed_a", "scaled", "fixed_b"]:
			if int(ranges[index].get(key, -99)) != int(expected[index][key]): return false
		var scale: Vector2 = ranges[index].get("scale", Vector2(-1, -1))
		if not scale.is_equal_approx(expected[index].scale): return false
		var boundary: Vector2 = ranges[index].get("fixed_a_scale", Vector2.ZERO)
		var expected_boundary := Vector2.ZERO if index == 2 else Vector2(0.05, 0.05)
		if not boundary.is_equal_approx(expected_boundary): return false
	var diamond_end: Vector2 = ranges[0].get("fixed_b_scale", Vector2.ZERO)
	if not diamond_end.is_equal_approx(Vector2(0.05, 0.05)): return false
	return true

func _same_stored_value(before: Variant, after: Variant, visited: Dictionary, path: String) -> bool:
	# Compare saved authored data recursively, including other weapons' skills.
	# Resource identity/path IDs are not authored content and change on cold load.
	if typeof(before) != typeof(after):
		preservation_difference = path + ":type"
		return false
	if before is Resource:
		if before is Script:
			return before.resource_path == after.resource_path
		if before.has_method("get_saved_content_signature") and after.has_method("get_saved_content_signature"):
			# Skill drafts deliberately omit the editor-only Reset placeholder
			# and expired runtime caches on Save. Compare their canonical authored
			# content instead of treating those persistence rules as data loss.
			var same := String(before.call("get_saved_content_signature")) == String(after.call("get_saved_content_signature"))
			if not same: preservation_difference = path + ":authored_content_signature"
			return same
		var pair := "%d:%d" % [before.get_instance_id(), after.get_instance_id()]
		if visited.has(pair): return true
		visited[pair] = true
		for property: Dictionary in before.get_property_list():
			var key := String(property.name)
			if (int(property.usage) & PROPERTY_USAGE_STORAGE) == 0 or key in ["resource_path", "resource_scene_unique_id"]:
				continue
			if not _same_stored_value(before.get(key), after.get(key), visited, path + "/" + key): return false
		return true
	if before is Dictionary:
		if before.size() != after.size():
			preservation_difference = path + ":dictionary_size"
			return false
		for key: Variant in before:
			if not after.has(key) or not _same_stored_value(before[key], after[key], visited, path + "/" + str(key)): return false
		return true
	if before is Array:
		if before.size() != after.size():
			preservation_difference = path + ":array_size"
			return false
		for index in range(before.size()):
			if not _same_stored_value(before[index], after[index], visited, path + "/%d" % index): return false
		return true
	if before != after:
		preservation_difference = path + ":value"
		return false
	return true

func _find_profile(source: Resource, label: String) -> Dictionary:
	for profile: Dictionary in source.get("saved_profiles"):
		if String(profile.get("label", "")).nocasecmp_to(label) == 0:
			return profile.duplicate(true)
	return {}

func _record(event: String, data: Dictionary = {}) -> void:
	var row := data.duplicate(true)
	row["event"] = event
	row["elapsed_ms"] = float(Time.get_ticks_usec() - began_usec) / 1000.0
	events.append(row)
	print("TAPER_TEST ", JSON.stringify(row))
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var output := FileAccess.open(report_path, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify({"events": events}, "\t"))
		output.flush()

func _finish(ok: bool, reason: String) -> void:
	_record("finished", {"ok": ok, "reason": reason})
	quit(0 if ok else 1)
