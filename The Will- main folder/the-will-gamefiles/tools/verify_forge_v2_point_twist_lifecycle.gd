extends SceneTree

# Isolated authoring and history fixtures. No player/WIP library is loaded.
const Authoring = preload("res://runtime/forge_v2/forge_v2_authoring_state.gd")
const Stage = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const Profiles = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const Body = preload("res://runtime/forge_v2/forge_v2_material_body.gd")
const OUTPUT := "C:/WORKSPACE/test_artifacts/forge_v2_point_twist_lifecycle_20261017.json"
const STATE_PATH := "C:/WORKSPACE/test_artifacts/forge_v2_point_twist_lifecycle_state.tres"
var checks := 0
var failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var started := Time.get_ticks_usec()
	_test_append_history()
	_test_handle_mode_conversion()
	_test_handle_change()
	_test_spline_generation()
	_test_invalid_persisted_roll()
	var report := {
		"ok": failures.is_empty(), "checks": checks, "failures": failures,
		"duration_ms": float(Time.get_ticks_usec() - started) / 1000.0,
	}
	DirAccess.make_dir_recursive_absolute(OUTPUT.get_base_dir())
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
	for failure: String in failures:
		push_error(failure)
	print("Forge V2 twist lifecycle: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _state(tool: StringName = Authoring.TOOL_HANDLES) -> Resource:
	var state: Resource = Authoring.new()
	state.call("reset_new_draft", "Twist lifecycle fixture")
	state.call("set_active_tool_id", tool)
	if tool == Authoring.TOOL_HANDLES:
		state.call("set_active_profile_id", Profiles.PROFILE_HANDLE_BUILDER)
		state.call("set_active_handle_path_mode_id", Authoring.HANDLE_PATH_MODE_THREE_POINT_LINEAR)
	return state


func _seed_points(state: Resource) -> void:
	for point: Vector3 in [Vector3(-0.1, 0, 0), Vector3.ZERO, Vector3(0.1, 0, 0)]:
		state.call("append_spline_line_point", point, Vector3.UP)


func _rolls(state: Resource) -> PackedFloat64Array:
	return state.get("spline_line_roll_degrees") as PackedFloat64Array


func _test_append_history() -> void:
	var stage: Node = Stage.new()
	root.add_child(stage)
	var state := _state(Authoring.TOOL_SPLINE_LINE)
	stage.set("active_authoring_state", state)
	stage.call("append_spline_line_point", Vector3(-0.1, 0, 0), Vector3.UP)
	stage.call("append_spline_line_point", Vector3.ZERO, Vector3.UP)
	stage.call("set_spline_line_point_roll_degrees", 1, 810.0)
	_check(int(stage.call("append_spline_line_point", Vector3(0.1, 0, 0), Vector3.UP)) == 2,
		"third point appends after authored full turns")
	_check(_rolls(state) == PackedFloat64Array([0, 810, 0]), "new point starts at zero without changing existing roll")
	_check(bool(stage.call("undo_latest_action")), "append action undoes")
	_check(_rolls(state) == PackedFloat64Array([0, 810]) and _aligned(state), "append undo preserves roll/point alignment")
	_check(bool(stage.call("redo_latest_action")), "append action redoes")
	_check(_rolls(state) == PackedFloat64Array([0, 810, 0]) and _aligned(state), "append redo preserves turns and alignment")
	stage.call("undo_latest_action")
	stage.call("undo_latest_action")
	_check(_rolls(state) == PackedFloat64Array([0, 0]), "roll undo remains correct after append undo")
	stage.call("redo_latest_action")
	stage.call("redo_latest_action")
	_check(_rolls(state) == PackedFloat64Array([0, 810, 0]), "mixed redo sequence restores exact authored rolls")
	stage.free()


func _aligned(state: Resource) -> bool:
	return (
		(state.get("spline_line_points") as PackedVector3Array).size() == _rolls(state).size()
		and (state.get("spline_line_surface_normals") as PackedVector3Array).size() == _rolls(state).size()
	)


func _test_handle_mode_conversion() -> void:
	var state := _state()
	_seed_points(state)
	state.call("set_spline_line_point_roll_degrees", 1, 360.0)
	state.call("set_spline_line_point_roll_degrees", 2, 720.0)
	_check(bool(state.call("set_active_handle_path_mode_id", Authoring.HANDLE_PATH_MODE_TWO_POINT_LINEAR)), "three to two point conversion accepted")
	_check(_rolls(state) == PackedFloat64Array([0, 720]) and _aligned(state), "two point conversion retains unwrapped endpoints")
	_check(bool(state.call("set_active_handle_path_mode_id", Authoring.HANDLE_PATH_MODE_THREE_POINT_LINEAR)), "two to three point conversion accepted")
	_check(_rolls(state) == PackedFloat64Array([0, 360, 720]) and _aligned(state), "inserted midpoint interpolates full turns")
	var dense := _state()
	for point: Vector3 in [Vector3(-0.1, 0, 0), Vector3(0, 0.2, 0), Vector3(0.1, 0, 0)]:
		dense.call("append_spline_line_point", point, Vector3.UP)
	dense.call("set_spline_line_point_roll_degrees", 1, 15000.0)
	dense.call("set_spline_line_point_roll_degrees", 2, 30000.0)
	_check(_rolls(dense) == PackedFloat64Array([0, 15000, 30000]), "long angled path allows dense fixture")
	var before := dense.call("capture_editor_transient_snapshot") as Dictionary
	_check(not bool(dense.call("set_active_handle_path_mode_id", Authoring.HANDLE_PATH_MODE_TWO_POINT_LINEAR)), "shorter mode cannot silently discard excessive twist density")
	_check((dense.call("capture_editor_transient_snapshot") as Dictionary) == before, "rejected mode restores exact authoring snapshot")


func _test_handle_change() -> void:
	var state := _state()
	_seed_points(state)
	state.call("set_spline_line_point_roll_degrees", 1, 810.0)
	_check(bool(state.call("generate_profile_extrusion_from_spline")), "Handle fixture generates")
	var original := state.call("get_selected_material_body") as Resource
	if not _check(original != null, "Handle fixture exists"):
		return
	var original_polygon: PackedVector2Array = original.get("profile_polygon_2d_meters")
	_check(bool((state.call("begin_handle_change") as Dictionary).get("ok", false)), "Change Handle opens")
	_check(_rolls(state) == PackedFloat64Array([0, 810, 0]), "Change Handle restores source rolls")
	state.call("set_spline_line_point_roll_degrees", 1, -450.0)
	_check(bool(state.call("cancel_handle_change")), "Change Handle cancels")
	var restored := state.call("get_selected_material_body") as Resource
	_check(restored == original and restored.get("path_roll_degrees") == PackedFloat64Array([0, 810, 0]), "cancel restores original body and roll values")
	_check(bool((state.call("begin_handle_change") as Dictionary).get("ok", false)), "Change Handle reopens")
	state.call("set_spline_line_point_roll_degrees", 1, -450.0)
	var snapshot := state.call("capture_editor_transient_snapshot") as Dictionary
	var preview := state.call("build_spline_roll_preview_body") as Resource
	_check(preview != null and preview.get("path_roll_degrees") == PackedFloat64Array([0, -450, 0]), "Change Handle preview follows unwrapped edited rolls")
	_check((state.call("capture_editor_transient_snapshot") as Dictionary) == snapshot, "preview does not mutate authoring snapshot")
	_check(bool((state.call("apply_handle_change") as Dictionary).get("ok", false)), "roll-only Handle change applies")
	var changed := state.call("get_selected_material_body") as Resource
	if _check(changed != null, "changed Handle exists"):
		_check(changed.get("path_roll_degrees") == PackedFloat64Array([0, -450, 0]), "roll-only replacement stores edited values")
		_check(changed.get("profile_polygon_2d_meters") == original_polygon, "roll-only replacement preserves source profile")
	_check(_rolls(state).is_empty(), "Handle generate/change clears editor rolls")


func _test_spline_generation() -> void:
	var state := _state(Authoring.TOOL_SPLINE_LINE)
	_seed_points(state)
	state.call("set_spline_line_point_roll_degrees", 1, 810.0)
	_check(bool(state.call("generate_spline_line_csg_noodle")), "ordinary Spline Line generates with point twist")
	var body := state.call("get_selected_material_body") as Resource
	if _check(body != null, "ordinary Spline Line generated body exists"):
		_check(body.get("path_roll_degrees") == PackedFloat64Array([0, 810, 0]), "ordinary Spline Line carries roll to generated body")
	_check(_rolls(state).is_empty(), "ordinary Spline Line generation clears editor rolls")


func _test_invalid_persisted_roll() -> void:
	var state := _state()
	_seed_points(state)
	state.set("spline_line_roll_degrees", PackedFloat64Array([0, 50000, 0]))
	DirAccess.make_dir_recursive_absolute(STATE_PATH.get_base_dir())
	_check(ResourceSaver.save(state, STATE_PATH) == OK, "stale density fixture saves in isolated artifact")
	var loaded := ResourceLoader.load(STATE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not _check(loaded != null, "stale density fixture reloads"):
		return
	loaded.call("normalize")
	_check(_rolls(loaded) == PackedFloat64Array([0, 50000, 0]), "normalization does not reduce saved excessive turns")
	_check(not bool((loaded.call("get_spline_line_roll_status") as Dictionary).get("valid", true)), "stale saved density is invalid")
	_check(not bool(loaded.call("can_generate_profile_extrusion_from_spline")), "invalid saved density blocks generation readiness")
	_check(not bool(loaded.call("generate_profile_extrusion_from_spline")), "invalid saved density cannot generate Handle")
	_check((loaded.get("material_bodies") as Array).is_empty(), "rejected saved density publishes no body")
	var corrupt := _state()
	_seed_points(corrupt)
	corrupt.set("spline_line_roll_degrees", PackedFloat64Array([0, NAN, 0]))
	corrupt.call("normalize")
	_check(is_nan(_rolls(corrupt)[1]), "normalization preserves malformed value for rejection")
	_check(not bool(corrupt.call("can_generate_profile_extrusion_from_spline")), "nonfinite persisted twist cannot generate")
	var mismatched := _state()
	_seed_points(mismatched)
	mismatched.set("spline_line_roll_degrees", PackedFloat64Array([0, 720]))
	mismatched.call("normalize")
	_check(_rolls(mismatched) == PackedFloat64Array([0, 720]), "nonempty malformed roll count is not silently repaired")
	_check(not bool(mismatched.call("can_generate_profile_extrusion_from_spline")), "malformed roll count cannot generate")
	var body: Resource = Body.new()
	body.set("shape_kind", Body.SHAPE_KIND_SPLINE_PROFILE_PATH)
	body.set("path_points", PackedVector3Array([Vector3.ZERO, Vector3.RIGHT]))
	body.call("normalize")
	_check(body.get("path_roll_degrees") == PackedFloat64Array([0, 0]), "old body without roll data receives neutral defaults")


func _check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
	return condition
