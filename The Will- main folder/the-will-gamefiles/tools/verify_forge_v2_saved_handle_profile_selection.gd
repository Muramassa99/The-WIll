extends SceneTree

## Uses the real Forge UI selection/save paths with a frozen workspace library.
## No production saves, character, Skill Crafter scene, or grip solver are used.
## Godot 4.7 ItemList and ResourceLoader documentation checked before writing.
const UiScene = preload("res://scenes/ui_v2/crafting_bench_ui_v2.tscn")
const Stage = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const Profiles = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const ProfileLibrary = preload("res://core/models/player_tool_profile_library_state.gd")
const WipLibrary = preload("res://core/models/player_forge_wip_library_state.gd")
const Keybindings = preload("res://runtime/forge_v2/forge_v2_keybinding_state.gd")
const Fixture = preload("res://tools/grip_plane_proof/linear_handle_template_fixture.gd")
const Adapter = preload("res://runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd")
const HandlePacket = preload("res://core/resolvers/primary_grip_handle_mesh_packet.gd")
const Forge = preload("res://services/forge_service.gd")
const Section = preload("res://runtime/player/grip/prepared_weapon_plane_section.gd")
const OUTLINE_TOLERANCE_M := 0.00005
const BODY_TOLERANCE_M := 0.0000005
const SAVE_TIMEOUT_MSEC := 45000

class FakePlayer extends Node:
	var library: PlayerForgeWipLibraryState
	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return library

var _ui: CanvasLayer
var _stage: Node
var _library: PlayerForgeWipLibraryState
var _output_dir: String
var _started: int
var _finished := false
var _checks: Array[Dictionary] = []
var _failures: Array[String] = []
var _phases: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_started = Time.get_ticks_msec()
	_output_dir = "C:/WORKSPACE/test_artifacts/forge_saved_profile_selection_" + Time.get_datetime_string_from_system().replace(":", "-")
	DirAccess.make_dir_recursive_absolute(_output_dir)
	create_timer(120.0).timeout.connect(_on_watchdog)
	if not _check(FileAccess.get_sha256(Fixture.SOURCE_PATH) == Fixture.SOURCE_SHA256, "frozen source library hash matches"):
		_finish(); return
	var frozen := ResourceLoader.load(Fixture.SOURCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as Resource
	if not _check(frozen != null, "frozen source library loads"):
		_finish(); return
	var saved_profiles: Array = frozen.call("get_saved_profiles", Profiles.PROFILE_FAMILY_HANDLE)
	if not _check(not saved_profiles.is_empty(), "saved Handle profiles exist"):
		_finish(); return
	saved_profiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_name := String(a.get("label", ""))
		var b_name := String(b.get("label", ""))
		return a_name.length() > b_name.length() if a_name.length() != b_name.length() else a_name < b_name)
	var first: Dictionary = saved_profiles[0]
	var first_compiled: Dictionary = Profiles.compile_handle_profile_runtime_data(first)
	var first_runtime: Dictionary = first_compiled.get("compiled_profile", {})
	if not _check(first_runtime.get("valid", false), "longest named profile compiles"):
		_finish(); return
	_library = WipLibrary.new()
	_library.save_file_path = _output_dir + "/wips.tres"
	var player := FakePlayer.new()
	player.library = _library
	root.add_child(player)
	_stage = Stage.new()
	root.add_child(_stage)
	_ui = UiScene.instantiate() as CanvasLayer
	var profiles := ProfileLibrary.new()
	profiles.saved_profiles = frozen.get("saved_profiles").duplicate(true)
	profiles.save_file_path = _output_dir + "/profiles.tres"
	_ui.set("tool_profile_library_state", profiles)
	var keys := Keybindings.new()
	keys.save_file_path = _output_dir + "/keys.json"
	_ui.set("keybinding_state", keys)
	root.add_child(_ui)
	await process_frame
	_ui.call("open_for", player, _stage, "Saved profile selection regression")
	await process_frame
	await physics_frame
	_ui.call("_activate_handle_authoring_tool", &"handle_path_2_point_linear")
	if not _select_profile(first, "initial"):
		_finish(); return
	for point: Vector3 in [Vector3(-0.20, 0, 0), Vector3(0.20, 0, 0)]:
		if not _check(int(_stage.call("append_spline_line_point", point, Vector3.UP)) >= 0, "initial: append linear Handle point"):
			_finish(); return
	_ui.call("_generate_active_profile_extrusion")
	var state := _stage.call("get_active_authoring_state") as Resource
	var handle: Dictionary = Adapter.resolve_valid_handle_body(state)
	if not _check(handle.get("valid", false), "initial: generated Handle resolves"):
		_finish(); return
	_check_body(handle.body, first, "initial pending")
	if not await _save_and_inspect(first, "initial"):
		_finish(); return
	_check(FileAccess.get_sha256(Fixture.SOURCE_PATH) == Fixture.SOURCE_SHA256, "frozen source library remains unchanged")
	_finish()

func _select_profile(profile: Dictionary, phase: String) -> bool:
	_ui.call("_ensure_profile_saved_profiles_popup")
	_ui.call("_refresh_profile_saved_profiles_popup")
	var items := _ui.get("profile_saved_profiles_item_list") as ItemList
	var profile_id := StringName(profile.get("profile_id", StringName()))
	if not _check(items != null, phase + ": actual saved-profile ItemList exists"):
		return false
	var found := -1
	for index: int in items.item_count:
		if StringName(items.get_item_metadata(index)) == profile_id:
			found = index; break
	if not _check(found >= 0, phase + ": selected profile is in actual UI list"):
		return false
	_ui.call("_on_profile_saved_profile_item_clicked", found, Vector2.ZERO, MOUSE_BUTTON_LEFT)
	var state := _stage.call("get_active_authoring_state") as Resource
	var selected_ok := _check(StringName(state.get("active_handle_source_profile_id")) == profile_id and StringName(_ui.get("editor_loaded_saved_profile_id")) == profile_id,
		phase + ": callback retains selected profile ID")
	var editor_data: Dictionary = state.call("build_active_tool_profile_preset_data", "Selection regression")
	var editor_runtime: Dictionary = editor_data.get("compiled_profile", {})
	var compiled: Dictionary = Profiles.compile_handle_profile_runtime_data(profile)
	var expected: Dictionary = compiled.get("compiled_profile", {})
	var comparison := _compare_polygons(editor_runtime.get("deposition_polygon_2d_meters", PackedVector2Array()), expected.get("deposition_polygon_2d_meters", PackedVector2Array()))
	_check(comparison.matches, phase + ": selected editor polygon matches saved profile", comparison)
	_phases.append({"phase": phase, "profile_id": String(profile_id), "profile_label": String(profile.get("label", "")), "selected_list_index": found,
		"editor_comparison": comparison, "elapsed_ms": Time.get_ticks_msec() - _started})
	return selected_ok and bool(expected.get("valid", false))

func _check_body(body: Resource, profile: Dictionary, label: String) -> void:
	var compiled: Dictionary = Profiles.compile_handle_profile_runtime_data(profile)
	var runtime: Dictionary = compiled.get("compiled_profile", {})
	var comparison := _compare_polygons(body.get("profile_polygon_2d_meters"), runtime.get("deposition_polygon_2d_meters", PackedVector2Array()))
	_check(comparison.matches, label + ": authored body polygon matches selected profile", comparison)
	var snapshot: Dictionary = body.get("handle_profile_authoring_snapshot")
	_check(StringName(snapshot.get("source_profile_id", StringName())) == StringName(profile.get("profile_id", StringName())), label + ": body snapshot retains selected source profile ID")
	_check(absf(float(body.get("profile_rotation_bias_degrees")) - float(compiled.get("rotation_degrees", 0))) < 0.000001, label + ": authored rotation matches selected profile")

func _save_and_inspect(profile: Dictionary, phase: String) -> bool:
	if not _check(bool(_ui.call("_save_current_v2_draft")), phase + ": Save request accepted"):
		return false
	var deadline := Time.get_ticks_msec() + SAVE_TIMEOUT_MSEC
	var progress: Array[String] = []
	while bool(_ui.get("v2_save_in_progress")) and Time.get_ticks_msec() < deadline:
		var indicator := _ui.get("v2_save_progress_label") as Label
		if indicator != null and (progress.is_empty() or progress.back() != indicator.text):
			progress.append(indicator.text)
		await process_frame
	var label := _ui.get("v2_save_progress_label") as Label
	var status := _ui.get("action_status_label") as Label
	if not _check(not bool(_ui.get("v2_save_in_progress")) and label != null and label.text == "Saved", phase + ": Save completed successfully",
		{"progress": progress, "feedback": label.text if label != null else "missing", "status": status.text if status != null else "missing"}):
		return false
	var saved_id := StringName(_stage.call("get_active_saved_wip_id"))
	var saved := _library.get_saved_wip_clone(saved_id, false)
	if not _check(saved != null, phase + ": in-memory saved WIP exists"):
		return false
	_inspect_saved(saved, profile, phase + " in memory")
	var disk := ResourceLoader.load(_library.save_file_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PlayerForgeWipLibraryState
	if not _check(disk != null, phase + ": fresh persisted library loads"):
		return false
	var reloaded := disk.get_saved_wip_clone(saved_id, false)
	if not _check(reloaded != null, phase + ": persisted WIP exists"):
		return false
	_inspect_saved(reloaded, profile, phase + " disk")
	return true

func _inspect_saved(saved: CraftedItemWIP, profile: Dictionary, label: String) -> void:
	var resolved: Dictionary = Adapter.resolve_valid_handle_body(saved.forge_v2_authoring_state)
	if not _check(resolved.get("valid", false), label + ": saved authored Handle resolves"):
		return
	var body: Resource = resolved.body
	_check_body(body, profile, label)
	var packet: Dictionary = Forge.new()._build_forge_v2_runtime_mesh_packet(saved)
	if not _check(HandlePacket.validate(packet).get("valid", false), label + ": saved physical Handle packet validates"):
		return
	_check(String(packet.get("primary_grip_handle_body_signature", "")) == HandlePacket.build_body_signature(body), label + ": physical mesh carries current authored signature")
	var vertices: PackedVector3Array = packet.primary_grip_handle_vertices
	var indices: PackedInt32Array = packet.primary_grip_handle_indices
	var faces := PackedVector3Array()
	faces.resize(indices.size())
	for index: int in indices.size(): faces[index] = vertices[indices[index]]
	var paths: PackedVector3Array = body.get("path_points")
	var compiled: Dictionary = Profiles.compile_handle_profile_runtime_data(profile)
	var runtime: Dictionary = compiled.get("compiled_profile", {})
	var tangent := (paths[-1] - paths[0]).normalized()
	# Named fixture plane -> WeaponRootOrigin -> RL_BoneRoot (identity placement).
	var frame: Dictionary = Profiles.resolve_profile_path_frame(tangent, Vector3.UP, runtime.contact_direction_2d, float(compiled.get("rotation_degrees", 0)))
	var plane := Transform3D(Basis(frame.axis_x, frame.axis_y, frame.tangent), paths[0].lerp(paths[-1], 0.47))
	var helper := Section.new()
	var prepared: Dictionary = helper.prepare({"valid": true, "triangles_world": faces, "surface_source_origin_id": &"WeaponRootOrigin", "resolved_world_origin_id": &"RL_BoneRoot"}, plane, &"SavedHandleProfileVerificationPlane")
	var section: Dictionary = helper.slice(prepared, plane)
	if not _check(section.get("valid", false), label + ": saved physical midsection slices", {"reason": section.get("reason", "")}):
		return
	var expected := PackedVector2Array()
	for point: Vector2 in runtime.deposition_polygon_2d_meters:
		# Existing native Handle CSG mirrors the profile X coordinate.
		expected.append(Vector2(-point.x, point.y))
	var actual: PackedVector2Array = section.polygon
	var maximum_error := maxf(_outline_error(expected, actual), _outline_error(actual, expected))
	_check(maximum_error <= OUTLINE_TOLERANCE_M, label + ": saved physical shape matches selected profile", {"maximum_outline_error_mm": maximum_error * 1000.0, "tolerance_mm": OUTLINE_TOLERANCE_M * 1000.0, "expected_points": expected.size(), "actual_points": actual.size(), "physical_triangles": indices.size() / 3})

func _compare_polygons(actual: PackedVector2Array, expected: PackedVector2Array) -> Dictionary:
	var maximum_error := 0.0
	if actual.size() != expected.size() or actual.size() < 3:
		return {"matches": false, "actual_points": actual.size(), "expected_points": expected.size()}
	for index: int in actual.size(): maximum_error = maxf(maximum_error, actual[index].distance_to(expected[index]))
	return {"matches": maximum_error <= BODY_TOLERANCE_M, "actual_points": actual.size(), "expected_points": expected.size(), "maximum_point_error_mm": maximum_error * 1000.0}

func _outline_error(points: PackedVector2Array, polygon: PackedVector2Array) -> float:
	var maximum_error := 0.0
	for point: Vector2 in points:
		var nearest := INF
		for index: int in polygon.size():
			var a := polygon[index]
			var b := polygon[(index + 1) % polygon.size()]
			var ab := b - a
			var weight := clampf((point - a).dot(ab) / maxf(ab.length_squared(), 1e-20), 0, 1)
			nearest = minf(nearest, point.distance_to(a + ab * weight))
		maximum_error = maxf(maximum_error, nearest)
	return maximum_error

func _check(ok: bool, description: String, detail: Dictionary = {}) -> bool:
	_checks.append({"ok": ok, "check": description, "detail": detail, "elapsed_ms": Time.get_ticks_msec() - _started})
	if not ok:
		_failures.append(description)
		push_error("SAVED_HANDLE_PROFILE_SELECTION: " + description + " " + str(detail))
	return ok

func _on_watchdog() -> void:
	if _finished: return
	_check(false, "whole diagnostic exceeded 120 second watchdog")
	_finish()

func _finish() -> void:
	if _finished: return
	_finished = true
	var report := {"ok": _failures.is_empty(), "source_path": Fixture.SOURCE_PATH, "source_sha256": Fixture.SOURCE_SHA256,
		"elapsed_ms": Time.get_ticks_msec() - _started, "phases": _phases, "checks": _checks, "failures": _failures,
		"scope": "Real Forge UI selection and Save; authored polygon plus in-memory/disk physical cross-section. No live Skill Crafter or grip solve."}
	var file := FileAccess.open(_output_dir + "/report.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print("SAVED_HANDLE_PROFILE_SELECTION: %s checks=%d failures=%d report=%s/report.json" % ["PASS" if _failures.is_empty() else "FAIL", _checks.size(), _failures.size(), _output_dir])
	if is_instance_valid(_ui): _ui.call("close_ui")
	quit(0 if _failures.is_empty() else 1)
