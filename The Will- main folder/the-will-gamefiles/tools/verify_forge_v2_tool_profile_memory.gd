extends SceneTree

const State = preload("res://runtime/forge_v2/forge_v2_authoring_state.gd")
const Controller = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const Profiles = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const WIP = preload("res://core/models/crafted_item_wip.gd")

const BASIC_TOOLS: Array[StringName] = [
	State.TOOL_VOLUME_STROKE, State.TOOL_SPLINE_LINE, State.TOOL_DETAILING_BRUSH,
]
const TEST_DIRECTORY := "user://diagnostics/forge_v2_tool_profile_memory"

var checks: Array[Dictionary] = []
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: Resource = State.new()
	state.call("reset_new_draft", "Tool profile memory verifier")
	_verify_defaults(state)
	_configure_profiles(state)
	_verify_profiles(state, "first round trip")
	_verify_profile_edit_routing(state)
	_verify_transient_restore(state)
	_verify_wip_save_reload(state)
	_verify_primitive_memory()
	await _verify_controller_selection_and_history()
	await _verify_profile_undo_after_other_tool_selections()
	await _verify_generated_action_profile_memory(false)
	await _verify_generated_action_profile_memory(true)
	_write_report()
	quit(0 if failures == 0 else 1)


func _verify_defaults(state: Resource) -> void:
	state.call("set_active_tool_id", State.TOOL_VOLUME_STROKE)
	state.call("select_active_saved_basic_profile", _basic_profile(9))
	for tool_id: StringName in [State.TOOL_SPLINE_LINE, State.TOOL_DETAILING_BRUSH]:
		state.call("set_active_tool_id", tool_id)
		_check(
			state.get("active_basic_shape_source_id") == State.BASIC_SHAPE_SOURCE_PRIMITIVE
			and state.get("active_saved_basic_profile_id") == StringName(),
			"Unused tool starts with its own default: %s" % tool_id
		)
	state.call("reset_new_draft", "Tool profile memory verifier")
	_check(
		state.get("active_saved_basic_profile_id") == StringName(),
		"New WIP resets remembered profiles"
	)


func _configure_profiles(state: Resource) -> void:
	for index in range(BASIC_TOOLS.size()):
		state.call("set_active_tool_id", BASIC_TOOLS[index])
		_check(
			bool(state.call("select_active_saved_basic_profile", _basic_profile(index))),
			"Basic profile compiles and is selected for tool %d" % index
		)
	state.call("set_active_tool_id", State.TOOL_HANDLES)
	state.call("set_active_profile_width_meters", 0.04)
	state.call("set_active_profile_height_meters", 0.03)
	state.call("set_active_profile_rotation_degrees", 27.0)
	state.call("set_active_profile_display_name", "Remembered Handle")
	state.set("active_handle_source_profile_id", &"remembered_handle_profile")
	state.call("set_active_handle_grid_snapping_enabled", true)
	state.call("set_active_operation_mode", State.OPERATION_REMOVE_MATERIAL)
	state.set("active_material_variant_id", &"memory_test_material")


func _verify_profiles(state: Resource, label: String) -> void:
	for index in range(BASIC_TOOLS.size()):
		state.call("set_active_tool_id", BASIC_TOOLS[index])
		_check(
			state.get("active_saved_basic_profile_id") == _profile_id(index),
			"%s: tool %d recalls its own saved profile ID" % [label, index]
		)
		var profile: Dictionary = state.get("active_saved_basic_profile_data")
		_check(
			profile.get("label") == "Memory profile %d" % index,
			"%s: tool %d recalls its own profile data" % [label, index]
		)
	state.call("set_active_tool_id", State.TOOL_HANDLES)
	_check(
		state.get("active_handle_source_profile_id") == &"remembered_handle_profile"
		and state.get("active_profile_display_name") == "Remembered Handle",
		"%s: Handle retains stable source ID and label" % label
	)
	_check(
		is_equal_approx(float(state.get("active_profile_width_meters")), 0.04)
		and is_equal_approx(float(state.get("active_profile_height_meters")), 0.03)
		and is_equal_approx(float(state.get("active_profile_rotation_degrees")), 27.0)
		and bool(state.get("active_handle_grid_snapping_enabled")),
		"%s: Handle retains authored dimensions, rotation and snapping" % label
	)


func _verify_profile_edit_routing(state: Resource) -> void:
	_check(
		state.get("active_operation_mode") == State.OPERATION_REMOVE_MATERIAL
		and state.get("active_material_variant_id") == &"memory_test_material",
		"Switching profiles leaves material and operation unchanged"
	)
	var memory: Dictionary = state.get("tool_profile_memory")
	for tool_id: Variant in memory:
		var profile: Dictionary = memory[tool_id]
		_check(
			not profile.has("active_operation_mode")
			and not profile.has("active_material_variant_id")
			and not profile.has("active_amount_ratio")
			and not profile.has("spline_line_points")
			and not profile.has("active_handle_path_mode_id"),
			"Memory contains profile configuration only: %s" % tool_id
		)
	for tool_id: StringName in [State.TOOL_SPLINE_LINE, State.TOOL_DETAILING_BRUSH]:
		var edited: Resource = state.duplicate(true)
		edited.call("set_active_tool_id", tool_id)
		if tool_id == State.TOOL_DETAILING_BRUSH:
			var controls := PackedVector3Array([Vector3.ZERO, Vector3(0.2, 0.0, 0.0)])
			var normals := PackedVector3Array([Vector3.UP, Vector3.UP])
			var contacts := PackedVector3Array([Vector3.DOWN, Vector3.DOWN])
			_check(bool(edited.call(
				"replace_detailing_brush_path_solution", controls, normals,
				&"target_material_surface", &"profile_memory_surface_fixture",
				controls, normals, PackedInt32Array([0, 1]), [true], [&"none"],
				true, &"none", 0, contacts, contacts
			)), "Detailing path fixture satisfies the authoring contract")
		else:
			edited.call("append_spline_line_point", Vector3.ZERO, Vector3.UP)
			edited.call("append_spline_line_point", Vector3(0.2, 0.0, 0.0), Vector3.UP)
		var path_before: PackedVector3Array = edited.get("spline_line_points")
		_check(path_before.size() == 2, "Profile editing starts with a real unfinished path: %s" % tool_id)
		var source := _basic_profile(8)
		_check(bool(edited.call("apply_tool_profile_preset", source)), "Explicit profile editor load succeeds: %s" % tool_id)
		var loaded_points: PackedVector2Array = edited.get("active_basic_control_points_2d_meters")
		edited.call("set_active_basic_grid_snapping_enabled", true)
		_check(
			edited.get("active_tool_id") == tool_id
			and edited.get("active_basic_control_points_2d_meters") == loaded_points
			and edited.get("spline_line_points") == path_before,
			"Basic snapping preserves the active tool, loaded profile and path: %s" % tool_id
		)
		_check(
			bool(edited.call("set_active_basic_control_point_2d_meters", 0, loaded_points[0]))
			and edited.get("active_tool_id") == tool_id
			and edited.get("spline_line_points") == path_before,
			"Basic point editing keeps its tool and unfinished path: %s" % tool_id
		)
		edited.call("reset_active_basic_profile_builder")
		_check(
			edited.get("active_tool_id") == tool_id
			and edited.get("spline_line_points") == path_before,
			"Basic builder reset keeps its tool and unfinished path: %s" % tool_id
		)
		edited.call("set_active_tool_id", State.TOOL_VOLUME_STROKE)
		_check(edited.get("active_saved_basic_profile_id") == _profile_id(0), "Basic editor leaves Stroke profile memory intact: %s" % tool_id)


func _verify_transient_restore(state: Resource) -> void:
	var snapshot: Dictionary = state.call("capture_editor_transient_snapshot")
	state.call("set_active_profile_rotation_degrees", 63.0)
	state.call("set_active_tool_id", State.TOOL_SPLINE_LINE)
	state.call("select_active_saved_basic_profile", _basic_profile(7))
	_check(bool(state.call("restore_editor_transient_snapshot", snapshot)), "Transient snapshot restores")
	_verify_profiles(state, "transient restore")
	var independent: Resource = state.duplicate(true)
	independent.call("set_active_tool_id", State.TOOL_VOLUME_STROKE)
	independent.call("select_active_saved_basic_profile", _basic_profile(6))
	independent.call("set_active_tool_id", State.TOOL_HANDLES)
	_verify_profiles(state, "duplicate remains isolated")
	var legacy: Resource = State.new()
	legacy.call("reset_new_draft", "Legacy profile memory verifier")
	legacy.call("set_active_tool_id", State.TOOL_SPLINE_LINE)
	legacy.call("select_active_saved_basic_profile", _basic_profile(5))
	legacy.set("tool_profile_memory", {})
	legacy.call("normalize")
	legacy.call("set_active_tool_id", State.TOOL_HANDLES)
	legacy.call("set_active_tool_id", State.TOOL_SPLINE_LINE)
	_check(legacy.get("active_saved_basic_profile_id") == _profile_id(5), "Older WIP seeds memory from its active profile")


func _verify_wip_save_reload(state: Resource) -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIRECTORY)
	var wip: Resource = WIP.new()
	wip.set("forge_v2_authoring_state", state.duplicate(true))
	var save_path := TEST_DIRECTORY.path_join("profile_memory_wip.tres")
	var saved := ResourceSaver.save(wip, save_path)
	_check(saved == OK, "WIP containing profile memory saves")
	if saved != OK:
		return
	var loaded := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(loaded != null, "WIP containing profile memory reloads")
	if loaded == null:
		return
	var restored: Resource = loaded.get("forge_v2_authoring_state")
	_check(restored != null, "Reloaded WIP retains authoring state")
	if restored != null:
		restored.call("normalize")
		_verify_profiles(restored, "WIP reload")


func _verify_primitive_memory() -> void:
	var state: Resource = State.new()
	state.call("reset_new_draft", "Primitive profile memory verifier")
	state.call("set_active_primitive_id", &"primitive_rod")
	state.call("set_brush_radius_meters", 0.05)
	state.call("set_active_tool_id", State.TOOL_SPLINE_LINE)
	state.call("set_active_primitive_id", &"primitive_plate")
	state.call("set_brush_radius_meters", 0.10)
	state.call("set_active_tool_id", State.TOOL_VOLUME_STROKE)
	_check(
		state.get("active_primitive_id") == &"primitive_rod"
		and is_equal_approx(float(state.get("active_brush_radius_meters")), 0.05),
		"CSG Stroke recalls its primitive and radius"
	)
	var snapshot: Dictionary = state.call("capture_editor_transient_snapshot")
	state.call("set_active_tool_id", State.TOOL_SPLINE_LINE)
	_check(
		state.get("active_primitive_id") == &"primitive_plate"
		and is_equal_approx(float(state.get("active_brush_radius_meters")), 0.10),
		"Spline recalls its independent primitive and radius"
	)
	state.call("restore_editor_transient_snapshot", snapshot)
	_check(
		state.get("active_primitive_id") == &"primitive_rod"
		and is_equal_approx(float(state.get("active_brush_radius_meters")), 0.05),
		"Transient restore includes active primitive and radius"
	)


func _verify_controller_selection_and_history() -> void:
	var controller: Node = Controller.new()
	root.add_child(controller)
	var state: Resource = controller.call("ensure_authoring_state", "Profile memory controller")
	_configure_profiles(state)
	var history_before: Dictionary = controller.call("get_action_history_summary")
	_check(bool(controller.call("select_tool_for_authoring", State.TOOL_SPLINE_LINE)), "Plain controller tool activation succeeds")
	_check(state.get("active_saved_basic_profile_id") == _profile_id(1), "Controller restores Spline profile")
	_check(not bool(controller.call("select_tool_for_authoring", &"unknown_tool")), "Plain controller rejects unknown tools")
	controller.call("select_tool_for_authoring", State.TOOL_HANDLES)
	var history_after: Dictionary = controller.call("get_action_history_summary")
	_check(history_before.get("undo_count") == history_after.get("undo_count"), "Plain selection adds no authoring undo action")
	controller.call("set_active_profile_rotation_degrees", 38.0)
	_check(bool(controller.call("undo_latest_action")), "Profile edit can be undone")
	_check(is_equal_approx(float(state.get("active_profile_rotation_degrees")), 27.0), "Undo restores Handle profile rotation")
	_verify_profiles(state, "after profile undo")
	_check(bool(controller.call("redo_latest_action")), "Profile edit can be redone")
	_check(is_equal_approx(float(state.get("active_profile_rotation_degrees")), 38.0), "Redo restores Handle profile rotation")
	state.call("set_active_operation_mode", State.OPERATION_ADD_MATERIAL)
	state.call("set_active_material_variant_id", &"mat_iron_gray")
	for point: Vector3 in [Vector3(-0.2, 0.0, 0.0), Vector3.ZERO, Vector3(0.2, 0.0, 0.0)]:
		state.call("append_spline_line_point", point, Vector3.FORWARD)
	_check(bool(state.call("generate_profile_extrusion_from_spline")), "Handle fixture is generated")
	var body_count: int = (state.get("material_bodies") as Array).size()
	controller.call("select_tool_for_authoring", State.TOOL_SPLINE_LINE)
	controller.call("select_tool_for_authoring", State.TOOL_HANDLES)
	_check(
		not bool(state.call("is_handle_change_active"))
		and (state.get("material_bodies") as Array).size() == body_count,
		"Plain Handle selection leaves existing Handle in place"
	)
	var activation: Dictionary = controller.call("activate_handle_tool")
	_check(bool(activation.get("ok", false)) and bool(state.call("is_handle_change_active")), "Legacy Handle activation still reopens the existing Handle")
	controller.call("cancel_spline_line")
	controller.queue_free()
	await process_frame


func _verify_profile_undo_after_other_tool_selections() -> void:
	var controller: Node = Controller.new()
	root.add_child(controller)
	var state: Resource = controller.call("ensure_authoring_state", "Profile replay ownership")
	_configure_profiles(state)
	controller.call("set_active_profile_rotation_degrees", 38.0)
	# These ordinary selections are deliberately not undoable authoring edits.
	controller.call("select_tool_for_authoring", State.TOOL_SPLINE_LINE)
	controller.call("select_active_saved_basic_profile", _basic_profile(7))
	controller.call("select_tool_for_authoring", State.TOOL_DETAILING_BRUSH)
	controller.call("select_active_saved_basic_profile", _basic_profile(8))
	controller.call("select_tool_for_authoring", State.TOOL_VOLUME_STROKE)
	_check(bool(controller.call("undo_latest_action")), "Handle profile Undo succeeds after other tool selections")
	_check(
		state.get("active_tool_id") == State.TOOL_VOLUME_STROKE
		and state.get("active_saved_basic_profile_id") == _profile_id(0),
		"Undo of inactive Handle profile preserves foreground Stroke selection"
	)
	controller.call("select_tool_for_authoring", State.TOOL_SPLINE_LINE)
	_check(state.get("active_saved_basic_profile_id") == _profile_id(7), "Handle Undo preserves later Spline profile selection")
	controller.call("select_tool_for_authoring", State.TOOL_DETAILING_BRUSH)
	_check(state.get("active_saved_basic_profile_id") == _profile_id(8), "Handle Undo preserves later Detailing profile selection")
	controller.call("select_tool_for_authoring", State.TOOL_HANDLES)
	_check(is_equal_approx(float(state.get("active_profile_rotation_degrees")), 27.0), "Inactive Handle Undo changes its remembered rotation")
	# A different field of the same tool is independent from the rotation action.
	state.call("set_active_profile_display_name", "Later Handle name")
	controller.call("select_tool_for_authoring", State.TOOL_VOLUME_STROKE)
	_check(bool(controller.call("redo_latest_action")), "Handle Redo succeeds with independent later profile-field changes")
	_check(state.get("active_tool_id") == State.TOOL_VOLUME_STROKE, "Inactive Handle Redo preserves foreground tool")
	controller.call("select_tool_for_authoring", State.TOOL_HANDLES)
	_check(
		is_equal_approx(float(state.get("active_profile_rotation_degrees")), 38.0)
		and state.get("active_profile_display_name") == "Later Handle name",
		"Redo changes only the recorded Handle profile field"
	)
	controller.call("select_tool_for_authoring", State.TOOL_SPLINE_LINE)
	_check(state.get("active_saved_basic_profile_id") == _profile_id(7), "Redo preserves independent Spline memory")
	controller.call("select_tool_for_authoring", State.TOOL_DETAILING_BRUSH)
	_check(state.get("active_saved_basic_profile_id") == _profile_id(8), "Redo preserves independent Detailing memory")
	controller.call("select_tool_for_authoring", State.TOOL_HANDLES)
	state.call("set_active_profile_rotation_degrees", 49.0)
	controller.call("select_tool_for_authoring", State.TOOL_VOLUME_STROKE)
	_check(not bool(controller.call("undo_latest_action")), "Undo still rejects a changed source value in the owning profile")
	controller.call("select_tool_for_authoring", State.TOOL_HANDLES)
	_check(is_equal_approx(float(state.get("active_profile_rotation_degrees")), 49.0), "Rejected profile replay preserves the newer value")
	controller.queue_free()
	await process_frame


func _verify_generated_action_profile_memory(handle_action: bool) -> void:
	var controller: Node = Controller.new()
	root.add_child(controller)
	var state: Resource = controller.call("ensure_authoring_state", "Generated profile memory")
	_configure_profiles(state)
	state.call("set_active_operation_mode", State.OPERATION_ADD_MATERIAL)
	state.call("set_active_material_variant_id", &"mat_iron_gray")
	var owner_tool := State.TOOL_HANDLES if handle_action else State.TOOL_SPLINE_LINE
	var label := "Handle" if handle_action else "Spline"
	controller.call("select_tool_for_authoring", owner_tool)
	for point: Vector3 in [Vector3(-0.2, 0.0, 0.0), Vector3.ZERO, Vector3(0.2, 0.0, 0.0)]:
		state.call("append_spline_line_point", point, Vector3.UP)
	_check(bool(controller.call(
		"generate_profile_extrusion_from_spline" if handle_action else "generate_spline_line_csg_noodle"
	)), "%s snapshot fixture generates" % label)
	controller.call("select_tool_for_authoring", State.TOOL_VOLUME_STROKE)
	controller.call("select_active_saved_basic_profile", _basic_profile(7))
	controller.call("select_tool_for_authoring", State.TOOL_DETAILING_BRUSH)
	controller.call("select_active_saved_basic_profile", _basic_profile(8))
	controller.call("select_tool_for_authoring", State.TOOL_SPLINE_LINE if handle_action else State.TOOL_HANDLES)
	if handle_action:
		controller.call("select_active_saved_basic_profile", _basic_profile(9))
	else:
		state.call("set_active_profile_rotation_degrees", 53.0)
	controller.call("select_tool_for_authoring", State.TOOL_VOLUME_STROKE)
	var expected_profiles: Dictionary = (state.call("capture_editor_transient_snapshot") as Dictionary)["tool_profile_memory"]
	_check(bool(controller.call("undo_latest_action")), "%s document Undo succeeds after unrelated profile choices" % label)
	_check(
		state.get("active_tool_id") == owner_tool
		and (state.get("spline_line_points") as PackedVector3Array).size() == 3
		and int(state.call("get_pending_material_body_count")) == 0,
		"%s document Undo still restores its editable path" % label
	)
	_check_unrelated_profiles(state, owner_tool, expected_profiles, "%s document Undo" % label)
	_check(bool(controller.call("redo_latest_action")), "%s document Redo succeeds" % label)
	_check(int(state.call("get_pending_material_body_count")) == 1, "%s document Redo restores its generated body" % label)
	_check_unrelated_profiles(state, owner_tool, expected_profiles, "%s document Redo" % label)
	var layer := controller.call("commit_pending_material_bodies_as_layer") as Resource
	_check(layer != null, "%s generation commits" % label)
	controller.call("select_tool_for_authoring", State.TOOL_VOLUME_STROKE)
	controller.call("select_active_saved_basic_profile", _basic_profile(6))
	expected_profiles = (state.call("capture_editor_transient_snapshot") as Dictionary)["tool_profile_memory"]
	_check(bool(controller.call("undo_latest_action")), "%s committed generation Undo succeeds" % label)
	_check_unrelated_profiles(state, owner_tool, expected_profiles, "%s committed Undo" % label)
	_check(bool(controller.call("redo_latest_action")), "%s committed generation Redo succeeds" % label)
	_check_unrelated_profiles(state, owner_tool, expected_profiles, "%s committed Redo" % label)
	if handle_action and layer != null:
		_verify_handle_change_profile_memory(controller, state)
	controller.queue_free()
	await process_frame


func _verify_handle_change_profile_memory(controller: Node, state: Resource) -> void:
	controller.call("select_tool_for_authoring", State.TOOL_VOLUME_STROKE)
	var activation: Dictionary = controller.call("activate_handle_tool")
	_check(bool(activation.get("ok", false)) and bool(state.call("is_handle_change_active")), "Handle change begins from Stroke")
	_check(bool(controller.call("set_spline_line_point", 1, Vector3(0.0, 0.03, 0.0))), "Handle change edits the retained path")
	_check(bool(controller.call("generate_profile_extrusion_from_spline")), "Handle change applies")
	controller.call("select_tool_for_authoring", State.TOOL_VOLUME_STROKE)
	controller.call("select_active_saved_basic_profile", _basic_profile(5))
	var expected_profiles: Dictionary = (state.call("capture_editor_transient_snapshot") as Dictionary)["tool_profile_memory"]
	_check(bool(controller.call("undo_latest_action")), "Handle change Undo succeeds after later Stroke profile choice")
	_check(
		state.get("active_tool_id") == State.TOOL_VOLUME_STROKE
		and state.get("active_saved_basic_profile_id") == _profile_id(5),
		"Handle change Undo restores the preceding tool with its latest profile"
	)
	_check_unrelated_profiles(state, State.TOOL_HANDLES, expected_profiles, "Handle change Undo")
	_check(bool(controller.call("redo_latest_action")), "Handle change Redo succeeds")
	_check_unrelated_profiles(state, State.TOOL_HANDLES, expected_profiles, "Handle change Redo")


func _check_unrelated_profiles(
	state: Resource,
	owner_tool: StringName,
	expected_profiles: Dictionary,
	label: String
) -> void:
	var current_profiles: Dictionary = (state.call("capture_editor_transient_snapshot") as Dictionary)["tool_profile_memory"]
	for tool_id: Variant in expected_profiles:
		if tool_id != owner_tool:
			_check(current_profiles.get(tool_id) == expected_profiles[tool_id], "%s preserves unrelated profile: %s" % [label, tool_id])


func _basic_profile(index: int) -> Dictionary:
	var radius := 0.02 + 0.002 * index
	var points := PackedVector2Array([
		Vector2(-radius, -radius), Vector2(radius, -radius),
		Vector2(radius, radius), Vector2(-radius, radius),
	])
	return {
		"profile_id": _profile_id(index), "id": _profile_id(index),
		"label": "Memory profile %d" % index,
		"family": Profiles.PROFILE_FAMILY_BASIC,
		"control_points_2d_meters": points,
		"base_polygon_2d_meters": points, "polygon_2d_meters": points,
		"base_anchor_2d_meters": Vector2.ZERO,
		"anchor_x_meters": 0.0, "anchor_y_meters": 0.0,
		"rotation_degrees": 0.0,
	}


func _profile_id(index: int) -> StringName:
	return StringName("memory_profile_%d" % index)


func _check(passed: bool, label: String) -> void:
	checks.append({"passed": passed, "label": label})
	if not passed:
		failures += 1
		push_error(label)


func _write_report() -> void:
	var report_path := OS.get_environment("THE_WILL_TOOL_PROFILE_MEMORY_REPORT")
	if report_path.is_empty():
		report_path = TEST_DIRECTORY.path_join("report.json")
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var report := {"ok": failures == 0, "passed": checks.size() - failures, "failed": failures, "checks": checks}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print("Forge V2 tool profile memory: %d passed, %d failed. %s" % [checks.size() - failures, failures, report_path])
