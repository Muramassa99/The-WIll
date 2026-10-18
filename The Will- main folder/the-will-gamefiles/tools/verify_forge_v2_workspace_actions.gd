extends SceneTree

const UI_SCENE = preload("res://scenes/ui_v2/crafting_bench_ui_v2.tscn")
const CONTROLLER = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const EDITOR_SETTINGS = preload("res://core/models/forge_v2_editor_settings_state.gd")
const BINDINGS = preload("res://runtime/forge_v2/forge_v2_keybinding_state.gd")
const PROFILE_LIBRARY = preload("res://core/models/player_tool_profile_library_state.gd")
const PROFILES = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const REPORT := "C:/WORKSPACE/test_artifacts/forge_v2_workspace_actions_20261018.json"
const TOOL_ORDER: Array[StringName] = [
	&"tool_volume_stroke", &"tool_detailing_brush", &"tool_handles", &"tool_spline_line",
]
const ADD := &"operation_add_material"
const REMOVE := &"operation_remove_material"

var checks: Array[Dictionary] = []
var evidence: Dictionary = {}
var failures := 0
var ui: CanvasLayer
var controller: Node
var state: Resource
var actions: Node
var keys: Resource
var saved_screen_cursor := Vector2i.ZERO
var screen_cursor_warped := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 800)
	controller = CONTROLLER.new()
	var preferences: Resource = EDITOR_SETTINGS.new()
	preferences.set("save_file_path", "user://diagnostics/workspace_actions/editor_settings.tres")
	controller.set("editor_settings", preferences)
	root.add_child(controller)
	ui = UI_SCENE.instantiate() as CanvasLayer
	keys = BINDINGS.new()
	keys.set("save_file_path", "user://diagnostics/workspace_actions/keybindings.json")
	var profiles: Resource = PROFILE_LIBRARY.new()
	profiles.set("save_file_path", "user://diagnostics/workspace_actions/profiles.tres")
	ui.set("keybinding_state", keys)
	ui.set("tool_profile_library_state", profiles)
	root.add_child(ui)
	await process_frame
	# Null player intentionally prevents any Save Draft shortcut from writing a
	# real library. The save dispatch is checked through its missing-library result.
	ui.call("open_for", null, controller, "Workspace Actions Verify", null)
	await process_frame
	actions = ui.get("workspace_action_menu") as Node
	state = controller.call("get_active_authoring_state") as Resource
	if not _check(actions != null and actions.has_method("get_context"), "real UI owns workspace action helper"):
		await _finish()
		return
	_test_bindings()
	await _test_smoothing_settings()
	await _test_q_and_v()
	await _test_pending_tool_switch()
	await _test_legacy_tool_gate()
	await _test_apply_and_cancel()
	await _test_plain_s_apply_is_immediately_editable()
	await _test_stranded_legacy_path()
	await _test_handle_and_detail_dispatch()
	await _test_profile_recall_through_q()
	await _test_profile_builder_tool_gate()
	await _test_apply_waits_for_tool_availability()
	await _test_retained_selection_workflow()
	_test_held_history_stops()
	await _test_input_guards()
	await _finish()


func _test_bindings() -> void:
	for action: StringName in [BINDINGS.ACTION_TOOL_VOLUME_STROKE, BINDINGS.ACTION_TOOL_SPLINE_LINE, BINDINGS.ACTION_TOOL_HANDLES]:
		_check((keys.call("get_binding_data", action) as Dictionary).is_empty(), String(action) + " has no old B/L/H default")
	_check(_matches(BINDINGS.ACTION_TOOL_RADIAL, _key(KEY_Q)), "plain Q matches tool wheel")
	_check(not _matches(BINDINGS.ACTION_TOOL_RADIAL, _key(KEY_Q, true, true)), "Ctrl+Q does not match plain Q")
	_check(_matches(BINDINGS.ACTION_CONTEXT_ACTIONS, _key(KEY_S)), "plain S matches context actions")
	_check(not _matches(BINDINGS.ACTION_CONTEXT_ACTIONS, _key(KEY_S, true, true)), "Ctrl+S does not match plain S")
	_check(_matches(BINDINGS.ACTION_SAVE_DRAFT, _key(KEY_S, true, true)), "Ctrl+S keeps Save Draft binding")
	_check(_matches(BINDINGS.ACTION_RETAINED_EDIT, _key(KEY_E)), "plain E matches retained editing")
	_check(not _matches(BINDINGS.ACTION_RETAINED_EDIT, _key(KEY_E, true, true)), "Ctrl+E does not match plain E")
	for index in range(6):
		var code := KEY_1 + index
		var plain := _key(code)
		var shifted := _key(code)
		shifted.shift_pressed = true
		_check(_matches(BINDINGS.PROFILE_SLOT_ACTIONS[index], plain)
			and not _matches(BINDINGS.PROFILE_SLOT_ACTIONS[index], shifted), "profile slot %d reserves only exact plain number" % (index + 1))
	_fresh(&"tool_spline_line")
	var timestamp := float(state.get("updated_timestamp"))
	for code in [KEY_B, KEY_L, KEY_H]:
		ui.call("_input", _key(code))
		ui.call("_unhandled_input", _key(code))
	_check(_tool() == &"tool_spline_line" and float(state.get("updated_timestamp")) == timestamp,
		"old B/L/H defaults leave current authoring state unchanged")
	for code in range(KEY_1, KEY_6 + 1):
		_check(bool(actions.call("handle_input", _key(code))), "reserved number %d is consumed" % (code - KEY_1 + 1))
	_check(_tool() == &"tool_spline_line" and float(state.get("updated_timestamp")) == timestamp,
		"reserved profile numbers do not mutate authoring state")


func _test_smoothing_settings() -> void:
	ui.call("_refresh_settings_popup")
	var slider := ui.get("freehand_smoothing_slider") as HSlider
	_check(slider != null and is_equal_approx(slider.value, 4.0), "Settings displays default smoothing 4")
	if slider == null:
		return
	slider.value = 7.0
	_check(int(controller.call("get_freehand_smoothing_steps")) == 7, "Settings slider applies chosen smoothing")
	var disk := ResourceLoader.load("user://diagnostics/workspace_actions/editor_settings.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as Resource
	_check(disk != null and int(disk.get("freehand_smoothing_steps")) == 7, "Settings slider persists chosen smoothing to disk")
	controller.call("start_new_draft", "Settings retention")
	ui.call("_refresh_settings_popup")
	_check(is_equal_approx(slider.value, 7.0), "Settings refresh after new draft retains choice")
	await process_frame


func _test_q_and_v() -> void:
	_fresh(&"tool_volume_stroke")
	for index in TOOL_ORDER.size():
		_choose_q(index)
		_check(_tool() == TOOL_ORDER[index] and not _popup_open(), String(TOOL_ORDER[index]) + " Q release selects actual backend tool without prompt")
	controller.call("set_active_tool_id", &"tool_spline_line")
	for operation: StringName in [ADD, REMOVE]:
		controller.call("set_active_operation_mode", operation)
		_open_q()
		var radial := _radial()
		if radial == null:
			return
		_check(StringName(radial.call("get_selected_id")) == (&"operation_add" if operation == ADD else &"operation_remove"),
			"Q initially selects current operation " + String(operation))
		ui.call("_input", _key(KEY_Q, false))
		_check(_operation() == operation and not _q_open(), "Q release without motion preserves " + String(operation))
	_choose_operation(true)
	_check(_operation() == ADD and not _popup_open(), "Q inner left immediately selects Add")
	_choose_operation(false)
	_check(_operation() == REMOVE and not _popup_open(), "Q inner right immediately selects Remove")
	_open_q()
	var radial := _radial()
	if radial != null:
		var before_tool := _tool()
		var before_operation := _operation()
		_radial_pointer(radial, _radial_center(radial) + Vector2.UP * (float(radial.get("_outer_radius")) + 2.0))
		_check(StringName(radial.call("get_selected_id")) == &"", "pointer outside Q circle has no selected action")
		ui.call("_input", _key(KEY_Q, false))
		_check(_tool() == before_tool and _operation() == before_operation and not _q_open(), "outside Q release cancels without changing tool or operation")
	_open_q()
	await _capture("q")
	ui.call("_input", _key(KEY_ESCAPE))
	_check(not _q_open() and bool(ui.call("is_open")), "Escape closes Q while keeping Forge open")
	_hover_workspace()
	ui.call("_input", _key(KEY_V))
	var view_radial := ui.get("workspace_view_radial") as Control
	if _check(bool(ui.get("workspace_view_radial_active")) and view_radial != null, "V still opens original view wheel"):
		_check((view_radial.get("_entries") as Array).size() == 6 and (view_radial.get("_center_entries") as Array).is_empty(), "V retains six view entries and ordinary center")
		await _capture("v")
		_radial_pointer(view_radial, _radial_center(view_radial))
		ui.call("_input", _key(KEY_V, false))
		_check(not bool(ui.get("workspace_view_radial_active")) and not view_radial.visible, "V center release still cancels")
		_hover_workspace()
		ui.call("_input", _key(KEY_V))
		_radial_pointer(view_radial, _radial_center(view_radial) + Vector2.UP * float(view_radial.get("_outer_radius")) * 1.5)
		_check(StringName(view_radial.call("get_selected_id")) == &"top", "V remains directional beyond its outer ring")
		ui.call("_input", _key(KEY_ESCAPE))
		_check(not bool(ui.get("workspace_view_radial_active")), "V Escape still dismisses")


func _test_pending_tool_switch() -> void:
	_fresh(&"tool_spline_line")
	_append_path(3)
	var before := _points()
	_choose_q(3)
	_check(not _popup_open() and _points() == before, "Q selecting already active tool preserves unfinished path without a prompt")
	_choose_operation(false)
	_check(_operation() == REMOVE and not _popup_open() and _points() == before, "operation switch with unfinished path is immediate and preserves points")
	_choose_operation(true)
	_choose_q(0)
	_check(_popup_open() and _tool() == &"tool_spline_line" and _points() == before,
		"different Q tool opens Apply/Cancel before changing unfinished spline")
	_check(StringName(actions.get("pending_tool")) == &"tool_volume_stroke", "tool-switch popup remembers requested destination")
	await _capture("switch_popup")
	ui.call("_input", _key(KEY_ESCAPE))
	await process_frame
	_check(not _popup_open() and _tool() == &"tool_spline_line" and _points() == before
		and StringName(actions.get("pending_tool")) == &"", "Escape aborts pending switch and keeps exact unfinished points")
	_choose_q(0)
	var popup := _popup()
	if popup != null:
		popup.hide()
		await process_frame
		_check(not _popup_open() and actions.get("context_popup") == null and _points() == before
			and _tool() == &"tool_spline_line" and StringName(actions.get("pending_tool")) == &"",
			"native popup_hide dismissal drops pending switch and preserves exact points")
	_choose_q(0)
	popup = _popup()
	if popup != null and popup.is_embedded():
		await _click_outside_popup()
		_check(not _popup_open() and _tool() == &"tool_spline_line" and _points() == before
			and StringName(actions.get("pending_tool")) == &"", "actual outside embedder mouse click aborts tool switch and preserves points")
	else:
		evidence["outside_dismissal_boundary"] = "native OS outside-click dismissal needs manual testing; popup_hide signal path is separately verified"
		actions.call("dismiss")
	_choose_q(0)
	await _click_popup_button("Cancel")
	_check(not _popup_open() and _tool() == &"tool_volume_stroke" and _points().is_empty(),
		"actual Cancel button clears pending path through controller then switches tool")


func _test_legacy_tool_gate() -> void:
	_fresh(&"tool_spline_line")
	_append_path(3)
	var before := _points()
	ui.call("_set_active_v2_tool", &"tool_spline_line")
	_check(not _popup_open() and _points() == before, "legacy activation of same tool avoids prompt and preserves draft")
	ui.call("_set_active_v2_tool", &"tool_volume_stroke")
	_check(_popup_open() and _tool() == &"tool_spline_line" and _points() == before,
		"legacy direct tool activation uses unfinished-work gate")
	ui.call("_input", _key(KEY_ESCAPE))
	_press_shape_tool(&"tool_volume_stroke")
	_check(_popup_open() and _tool() == &"tool_spline_line" and _points() == before,
		"actual Shape Tool menu signal uses the same unfinished-work gate")
	await _click_popup_button("Cancel")
	_check(not _popup_open() and _tool() == &"tool_volume_stroke" and _points().is_empty(),
		"Shape Tool gate Cancel discards draft before applying menu tool choice")


func _test_apply_and_cancel() -> void:
	_fresh(&"tool_spline_line")
	_append_path(1)
	var before := _points()
	_choose_q(0)
	var apply := _popup_button("Apply")
	_check(apply != null and apply.disabled, "one-point invalid spline disables Apply")
	await _click_popup_button("Apply")
	_check(_popup_open() and _points() == before and _tool() == &"tool_spline_line", "disabled Apply keeps invalid path and aborts premature tool switch")
	ui.call("_input", _key(KEY_ESCAPE))
	controller.call("append_spline_line_point", Vector3(0.20, 0.03, 0.0), Vector3.UP)
	var bodies_before := _user_body_count()
	_choose_q(0)
	apply = _popup_button("Apply")
	_check(apply != null and not apply.disabled, "valid two-point spline enables Apply")
	await _click_popup_button("Apply")
	await _wait_for_context_completion("tool-switch spline Apply")
	_check(not _popup_open() and _points().is_empty() and _tool() == &"tool_volume_stroke"
		and _user_body_count() > bodies_before and _pending_body_count() == 0,
		"actual Apply button generates and commits spline material before switching tool")
	_fresh(&"tool_spline_line")
	_append_path(2)
	ui.call("_input", _key(KEY_S))
	_check(_popup_open() and StringName(actions.get("pending_tool")) == &"", "plain S opens current-context actions without pending tool switch")
	await _click_popup_button("Cancel")
	_check(not _popup_open() and _tool() == &"tool_spline_line" and _points().is_empty(), "S Cancel clears path and stays in current tool")
	_fresh(&"tool_volume_stroke")
	ui.call("_input", _key(KEY_S))
	var cancel := _popup_button("Cancel")
	apply = _popup_button("Apply")
	_check(apply != null and cancel != null and apply.disabled and cancel.disabled,
		"freehand context offers no invented Apply or cancel-last-stroke command")
	ui.call("_input", _key(KEY_ESCAPE))


func _test_plain_s_apply_is_immediately_editable() -> void:
	_fresh(&"tool_spline_line")
	_append_path(3)
	var original_points := _points()
	var bodies_before := _user_body_count()
	var undo_before := int(controller.call("get_action_history_summary").undo_count)
	ui.call("_input", _key(KEY_S))
	_check(_popup_open() and StringName(actions.get("pending_tool")) == &"", "plain S Apply fixture has no tool-switch request")
	await _click_popup_button("Apply")
	await _wait_for_context_completion("plain S spline Apply")
	_check(not _popup_open() and _points().is_empty() and _tool() == &"tool_spline_line",
		"plain S Apply completes generation without switching tools")
	_check(_pending_body_count() == 0 and _user_body_count() == bodies_before + 1,
		"plain S Apply commits its new spline without Save or a separate Commit action")
	var entries := state.call("get_retained_spline_editable_entries") as Array
	_check(entries.size() == 1, "plain S Apply immediately exposes its one retained editable spline")
	var history = controller.get("_action_history")
	var latest := history.call("peek_undo") as Dictionary
	_check(int(controller.call("get_action_history_summary").undo_count) == undo_before + 1
		and String(latest.get("label", "")) == "Generate CSG Noodle",
		"generation plus commit creates exactly one Generate action with no extra commit record")
	ui.call("_input", _key(KEY_E))
	_check(bool(ui.get("retained_edit_mode")) and not _popup_open(), "E can open immediately after plain S Apply without another confirmation")
	var preview := ui.get("workspace_preview") as Node3D
	var presenter := preview.get("volume_preview_presenter") as Node3D
	var hit: Dictionary = {}
	for frame in range(180):
		await process_frame
		var projected := preview.call("project_workspace_local_to_screen", original_points[1]) as Dictionary
		hit = preview.call("resolve_retained_edit_selection", projected.get("screen_position", Vector2.ZERO)) as Dictionary
		if bool(hit.get("valid", false)) and bool(hit.get("editable", false)):
			break
	_check(bool(hit.get("valid", false)) and bool(hit.get("editable", false))
		and entries.size() == 1 and StringName(hit.get("body_id", &"")) == StringName(entries[0].body_id),
		"E final-surface picking recognizes the freshly applied spline without saving")
	_check(int(presenter.get("retained_edit_selection").get("face_count")) > 0, "fresh Apply provides visible E selection geometry")
	ui.call("_input", _key(KEY_E))
	_check(bool(controller.call("undo_latest_action")), "one Undo accepts the committed Generate action")
	await process_frame
	_check(_user_body_count() == bodies_before and _pending_body_count() == 0 and _points() == original_points,
		"one Generate Undo removes committed geometry and restores its authored path")
	_check(int(controller.call("get_action_history_summary").undo_count) == undo_before,
		"Generate Undo returns to the pre-Apply history count")
	_check(bool(controller.call("redo_latest_action")), "one Redo accepts the Generate action")
	await process_frame
	await process_frame
	_check(_user_body_count() == bodies_before + 1 and _pending_body_count() == 0 and _points().is_empty()
		and (state.call("get_retained_spline_editable_entries") as Array).size() == 1,
		"one Generate Redo restores committed editable geometry without an extra commit")
	_check(int(controller.call("get_action_history_summary").undo_count) == undo_before + 1,
		"Generate Redo restores exactly one action")
	evidence["plain_s_commit_boundary"] = "Real S popup Apply, final-surface E pick, retained membership, zero pending bodies and one Generate Undo/Redo; no Save was called."


func _test_handle_and_detail_dispatch() -> void:
	_fresh(&"tool_handles")
	controller.call("reset_active_handle_profile_builder")
	for point: Vector3 in [Vector3(-0.20, 0, 0), Vector3.ZERO, Vector3(0.20, 0, 0)]:
		controller.call("append_spline_line_point", point, Vector3.UP)
	ui.call("_input", _key(KEY_S))
	var context: Dictionary = actions.call("get_context") as Dictionary
	_check(StringName(context.get("apply_method", &"")) == &"generate_profile_extrusion_from_spline"
		and bool(context.get("can_apply", false)), "Handle context enables its real profile extrusion command")
	await _click_popup_button("Apply")
	await _wait_for_context_completion("Handle Apply")
	_check(not _popup_open() and bool(state.call("has_handle_material_body")) and _points().is_empty() and _pending_body_count() == 0,
		"actual Handle Apply commits a semantic Handle and clears its draft path")
	var handle_count := int(state.call("get_handle_material_body_count"))
	controller.call("activate_handle_tool")
	_check(bool(state.call("is_handle_change_active")), "existing Handle fixture enters Change Handle")
	ui.call("_input", _key(KEY_S))
	await _click_popup_button("Cancel")
	_check(not _popup_open() and not bool(state.call("is_handle_change_active"))
		and int(state.call("get_handle_material_body_count")) == handle_count,
		"Handle Change Cancel restores existing Handle through normal cancellation")
	_fresh(&"tool_detailing_brush")
	_check(_install_detail_solution(), "valid existing-contract Detail solution fixture installs")
	var bodies_before := _user_body_count()
	ui.call("_input", _key(KEY_S))
	context = actions.call("get_context") as Dictionary
	_check(StringName(context.get("apply_method", &"")) == &"generate_detailing_brush"
		and bool(context.get("can_apply", false)), "Detail context enables its real surface generation command")
	await _click_popup_button("Apply")
	await _wait_for_context_completion("Detail Apply")
	_check(not _popup_open() and _points().is_empty() and _user_body_count() > bodies_before and _pending_body_count() == 0,
		"actual Detail Apply generates and commits material then clears the solved path")
	evidence["detail_boundary"] = "Tests command dispatch using a coherent solved surface path; surface picking is not reverified here"


func _install_detail_solution() -> bool:
	var controls := PackedVector3Array([Vector3(-0.10, 0, 0), Vector3.ZERO, Vector3(0.10, 0, 0)])
	var normals := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	var contacts := PackedVector3Array([Vector3.DOWN, Vector3.DOWN, Vector3.DOWN])
	var points := PackedVector3Array([controls[0], Vector3(-0.05, 0, 0), controls[1], Vector3(0.05, 0, 0), controls[2]])
	var dense_normals := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	var dense_contacts := PackedVector3Array([Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN])
	return bool(controller.call("replace_detailing_brush_path_solution", controls, normals, &"target_material_surface",
		&"workspace_actions_surface_fixture", points, dense_normals, PackedInt32Array([0, 2, 4]),
		[true, true], [&"none", &"none"], true, &"none", 0, contacts, dense_contacts))


func _test_stranded_legacy_path() -> void:
	_fresh(&"tool_spline_line")
	_append_path(3)
	_check(bool(controller.call("generate_spline_line_csg_noodle")) and _user_body_count() > 0,
		"legacy fixture starts with completed authored material")
	_append_path(2)
	# Recreate a legacy saved state directly: current selection is Stroke while
	# older unfinished points remain. Normal tool switching now guards this case.
	state.set("active_tool_id", &"tool_volume_stroke")
	ui.call("_refresh_from_controller")
	var before := _points()
	var bodies_before: Array = (state.get("material_bodies") as Array).duplicate()
	ui.call("_input", _key(KEY_S))
	var apply := _popup_button("Apply")
	var cancel := _popup_button("Cancel")
	_check(apply != null and apply.disabled and cancel != null and not cancel.disabled,
		"legacy stranded Stroke points enable only explicit Cancel without guessing an Apply tool")
	ui.call("_input", _key(KEY_ESCAPE))
	_check(not _popup_open() and _points() == before and (state.get("material_bodies") as Array) == bodies_before,
		"legacy stranded-path Escape preserves exact points and completed material")
	ui.call("_input", _key(KEY_S))
	await _click_popup_button("Cancel")
	_check(not _popup_open() and _tool() == &"tool_volume_stroke" and _points().is_empty()
		and (state.get("material_bodies") as Array) == bodies_before,
		"legacy stranded-path Cancel clears only unfinished points and retains completed material")


func _test_profile_builder_tool_gate() -> void:
	# Remember a nondefault destination profile. The requested builder must reset
	# it after Cancel; selecting the destination tool alone would recall this width.
	_fresh(&"tool_handles")
	controller.call("reset_active_handle_profile_builder")
	controller.call("set_active_profile_width_meters", 0.077)
	controller.call("select_tool_for_authoring", &"tool_spline_line")
	_append_path(3)
	var before := _points()
	var profile_before := StringName(state.get("active_profile_id"))
	ui.call("_open_profile_builder_popup")
	await process_frame
	var profile_window := ui.get("profile_builder_popup") as Window
	if not _check(is_instance_valid(profile_window) and profile_window.visible, "profile editor opens for cross-family pending work"):
		return
	ui.call("_select_profile_builder_handle_builder")
	var popup := _popup()
	_check(popup != null and popup.get_parent() == profile_window,
		"profile editor owns child Apply/Cancel for its cross-family builder request")
	_check(_popup_open() and _tool() == &"tool_spline_line" and _points() == before
		and StringName(state.get("active_profile_id")) == profile_before,
		"Spline to Handle builder does not discard pending points or change profile before confirmation")
	ui.call("_input", _key(KEY_ESCAPE))
	await process_frame
	_check(not _popup_open() and profile_window.visible and _tool() == &"tool_spline_line"
		and _points() == before and not (actions.get("pending_action") as Callable).is_valid(),
		"smallest Escape dismissal aborts builder callback and preserves parent profile editor and spline")
	ui.call("_select_profile_builder_handle_builder")
	popup = _popup()
	if popup != null and popup.is_embedded():
		await _click_outside_popup()
		_check(not _popup_open() and profile_window.visible and _tool() == &"tool_spline_line" and _points() == before,
			"outside child-popup click retains profile editor and unfinished spline")
	else:
		actions.call("dismiss")
	ui.call("_select_profile_builder_handle_builder")
	await _click_popup_button("Cancel")
	_check(not _popup_open() and profile_window.visible and _tool() == &"tool_handles" and _points().is_empty()
		and StringName(state.get("active_profile_id")) == PROFILES.PROFILE_HANDLE_BUILDER
		and is_equal_approx(float(state.get("active_profile_width_meters")), PROFILES.HANDLE_DEFAULT_WIDTH_METERS),
		"profile child Cancel clears spline then executes requested Handle builder reset and retains editor")
	ui.call("_close_profile_builder_popup")
	await process_frame

	_fresh(&"tool_volume_stroke")
	controller.call("reset_active_basic_profile_builder")
	controller.call("set_active_profile_width_meters", 0.083)
	controller.call("select_tool_for_authoring", &"tool_handles")
	_append_path(3)
	before = _points()
	profile_before = StringName(state.get("active_profile_id"))
	ui.call("_select_profile_builder_basic_builder")
	_check(_popup_open() and _tool() == &"tool_handles" and _points() == before
		and StringName(state.get("active_profile_id")) == profile_before,
		"Handle to Basic builder retains unfinished Handle path until an explicit choice")
	ui.call("_input", _key(KEY_ESCAPE))
	_check(not _popup_open() and _tool() == &"tool_handles" and _points() == before
		and not (actions.get("pending_action") as Callable).is_valid(),
		"dismissed Handle to Basic builder request leaves Handle work unchanged")
	ui.call("_select_profile_builder_basic_builder")
	await _click_popup_button("Cancel")
	_check(not _popup_open() and _tool() == &"tool_volume_stroke" and _points().is_empty()
		and StringName(state.get("active_profile_id")) == PROFILES.PROFILE_2D_BUILDER
		and is_equal_approx(float(state.get("active_profile_width_meters")), PROFILES.BASIC_BUILDER_DEFAULT_WIDTH_METERS),
		"Cancel clears Handle draft then executes requested Basic builder reset")
	for tool: StringName in [&"tool_spline_line", &"tool_detailing_brush"]:
		_fresh(tool)
		if tool == &"tool_detailing_brush":
			_check(_install_detail_solution(), "same-family Detail profile fixture has a real solved path")
		else:
			_append_path(2)
		before = _points()
		ui.call("_select_profile_builder_basic_builder")
		_check(not before.is_empty() and not _popup_open() and _tool() == tool and _points() == before,
			String(tool) + " same-family Basic builder stays in current tool and preserves points without prompt")


func _test_profile_recall_through_q() -> void:
	_fresh(&"tool_volume_stroke")
	for index in TOOL_ORDER.size():
		_choose_q(index)
		controller.call("set_active_profile_width_meters", 0.02 + float(index) * 0.01)
	for index in TOOL_ORDER.size():
		_choose_q(index)
		_check(is_equal_approx(float(state.get("active_profile_width_meters")), 0.02 + float(index) * 0.01),
			String(TOOL_ORDER[index]) + " Q activation recalls its independent profile width")


func _test_apply_waits_for_tool_availability() -> void:
	for abort_wait: bool in [false, true]:
		_fresh(&"tool_spline_line")
		_append_path(3)
		var bodies_before := _user_body_count()
		var completion := {"calls": 0, "busy_injected": false, "released": false}
		var after_select := func() -> void:
			completion["calls"] = int(completion["calls"]) + 1
		var block_after_generate := func(_changed_state: Resource) -> void:
			# Inject controller busy state only after the real generation command
			# emits its completed state, isolating deferred tool completion timing.
			if _points().is_empty() and _user_body_count() > bodies_before:
				controller.set("active_placement_body_id", &"workspace_actions_busy_fixture")
				completion["busy_injected"] = true
		actions.call("request_tool_change", &"tool_volume_stroke", after_select)
		controller.connect("authoring_state_changed", block_after_generate, CONNECT_ONE_SHOT)
		_inspect_and_release_apply_wait(completion, bodies_before, abort_wait)
		await _click_popup_button("Apply")
		for frame in range(360):
			if bool(completion["released"]):
				break
			await process_frame
		if controller.is_connected("authoring_state_changed", block_after_generate):
			controller.disconnect("authoring_state_changed", block_after_generate)
		controller.set("active_placement_body_id", StringName())
		_check(bool(completion["released"]), "deferred fixture releases its busy condition asynchronously (abort=%s)" % abort_wait)
		await _wait_for_context_completion("deferred Apply %s" % abort_wait)
		_check(not _popup_open() and not bool(actions.get("waiting_for_tool")) and _points().is_empty()
			and _user_body_count() == bodies_before + 1 and _pending_body_count() == 0
			and _tool() == (&"tool_spline_line" if abort_wait else &"tool_volume_stroke")
			and int(completion["calls"]) == (0 if abort_wait else 1),
			"Escape aborts queued switch while retaining committed applied material" if abort_wait
			else "commit completion selects queued tool and executes callback exactly once")
		await process_frame
		_check(int(completion["calls"]) == (0 if abort_wait else 1) and _user_body_count() == bodies_before + 1,
			"later frames cannot replay applied work or callback (abort=%s)" % abort_wait)
	evidence["busy_completion_boundary"] = "Real Apply generation, commit and mouse clicks; one-shot state signal injects a temporary busy condition, then an asynchronous observer verifies disabled duplicate Apply and releases it after the material-commit/tool wait starts."


func _inspect_and_release_apply_wait(completion: Dictionary, bodies_before: int, abort_wait: bool) -> void:
	var observed_wait := false
	for frame in range(360):
		await process_frame
		if bool(actions.get("waiting_for_material_commit")) or bool(actions.get("waiting_for_tool")):
			observed_wait = true
			break
	_check(observed_wait and bool(completion["busy_injected"]) and not bool(controller.call("can_select_tool_for_authoring"))
		and _popup_open() and _tool() == &"tool_spline_line" and _points().is_empty()
		and _user_body_count() == bodies_before + 1 and int(completion["calls"]) == 0,
		"successful Apply retains queued tool and callback during commit/tool wait (abort=%s)" % abort_wait)
	if observed_wait and _popup_open():
		var apply := _popup_button("Apply")
		var cancel := _popup_button("Cancel")
		_check(apply != null and apply.disabled and cancel != null and cancel.disabled,
			"material commit/tool wait disables Apply and Cancel (abort=%s)" % abort_wait)
		await _click_popup_button("Apply")
		_check(_user_body_count() == bodies_before + 1 and int(completion["calls"]) == 0 and _tool() == &"tool_spline_line",
			"actual second Apply click cannot repeat generated material while waiting (abort=%s)" % abort_wait)
		if abort_wait:
			ui.call("_input", _key(KEY_ESCAPE))
	controller.set("active_placement_body_id", StringName())
	completion["released"] = true


func _wait_for_context_completion(label: String) -> void:
	for frame in range(360):
		await process_frame
		if not bool(actions.get("waiting_for_material_commit")) and not bool(actions.get("waiting_for_tool")) \
			and not bool(actions.get("waiting_for_retained_apply")) and not _popup_open():
			return
	_check(false, label + " context completion timed out")


func _test_held_history_stops() -> void:
	_fresh(&"tool_spline_line")
	_append_path(3)
	ui.call("_input", _key(KEY_Z, true, true))
	_check(StringName(ui.get("action_history_hold_action")) == BINDINGS.ACTION_UNDO,
		"Undo fixture starts a held history action")
	var before := _points()
	_open_q()
	_check(StringName(ui.get("action_history_hold_action")) == &"", "opening Q ends a pre-existing held Undo")
	ui.call("_advance_action_history_hold", 2.0, false)
	_check(_points() == before, "held Undo cannot repeat behind Q")
	ui.call("_input", _key(KEY_ESCAPE))
	controller.call("append_spline_line_point", Vector3(0.18, 0, 0), Vector3.UP)
	ui.call("_input", _key(KEY_Z, true, true))
	_check(StringName(ui.get("action_history_hold_action")) == BINDINGS.ACTION_UNDO,
		"second Undo fixture starts a held history action")
	before = _points()
	ui.call("_input", _key(KEY_S))
	_check(_popup_open() and StringName(ui.get("action_history_hold_action")) == &"", "opening S ends a pre-existing held Undo")
	ui.call("_advance_action_history_hold", 2.0, false)
	_check(_points() == before, "held Undo cannot repeat behind S actions")
	ui.call("_input", _key(KEY_ESCAPE))
	ui.call("_input", _key(KEY_Z, false, true))


func _test_retained_selection_workflow() -> void:
	_fresh(&"tool_volume_stroke")
	var preview := ui.get("workspace_preview") as Node3D
	var presenter := preview.get("volume_preview_presenter") as Node3D
	var workspace := ui.get("workspace_view_container") as Control
	controller.call("set_placement_cursor_local_position", Vector3.ZERO, true)
	ui.call("_input", _key(KEY_E))
	_check(bool(ui.get("retained_edit_mode")) and not _popup_open(), "E enters selection without an unfinished draft")
	_check(workspace.mouse_default_cursor_shape == Control.CURSOR_ARROW, "E selection uses normal mouse pointer")
	var cursor := presenter.get("placement_cursor_mesh_instance") as MeshInstance3D
	_check(cursor == null or not cursor.visible, "E hides the deposition ball")
	controller.call("set_placement_cursor_local_position", Vector3(0.01, 0.01, 0.0), true)
	_check(cursor == null or not cursor.visible, "controller cursor refresh cannot restore deposition ball during E")
	var count := _user_body_count()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = workspace.size * 0.5
	click.pressed = true
	ui.call("_on_workspace_view_gui_input", click)
	click.pressed = false
	ui.call("_on_workspace_view_gui_input", click)
	_check(_user_body_count() == count and _points().is_empty(), "selection click cannot paint a new material body or path point")
	ui.call("_unhandled_input", _key(KEY_ESCAPE))
	_check(not bool(ui.get("retained_edit_mode")) and bool(ui.call("is_open")), "Escape exits selection while retaining Forge")
	ui.call("_input", _key(KEY_E))
	actions.call("request_tool_change", &"tool_spline_line")
	_check(_tool() == &"tool_spline_line" and not bool(ui.get("retained_edit_mode")), "choosing another tool leaves E selection")
	_append_path(3)
	var before := _points()
	ui.call("_input", _key(KEY_E))
	_check(_popup_open() and not bool(ui.get("retained_edit_mode")) and _points() == before, "E asks Apply/Cancel before replacing unfinished path context")
	ui.call("_input", _key(KEY_ESCAPE))
	_check(not _popup_open() and _points() == before and not bool(ui.get("retained_edit_mode")), "dismissing E entry prompt retains unfinished path")
	ui.call("_input", _key(KEY_E))
	await _click_popup_button("Cancel")
	_check(bool(ui.get("retained_edit_mode")) and _points().is_empty(), "E entry Cancel discards the old draft then enters selection")
	ui.call("_input", _key(KEY_E))
	_check(not bool(ui.get("retained_edit_mode")), "E toggles selection off without adding an authoring action")
	var text := LineEdit.new()
	root.add_child(text)
	text.grab_focus()
	await process_frame
	ui.call("_input", _key(KEY_E))
	_check(not bool(ui.get("retained_edit_mode")) and root.gui_get_focus_owner() == text, "text fields retain E instead of toggling selection")
	root.gui_release_focus()
	text.queue_free()
	await process_frame


func _test_input_guards() -> void:
	_fresh(&"tool_spline_line")
	_append_path(3)
	var before := _points()
	var status := ui.get("action_status_label") as Label
	ui.call("_set_v2_action_status_text", "held radial sentinel")
	_open_q()
	ui.call("_input", _key(KEY_Z, true, true))
	ui.call("_input", _key(KEY_Z, false, true))
	ui.call("_input", _key(KEY_S, true, true))
	_check(_points() == before and not _popup_open() and status.text == "held radial sentinel",
		"held Q consumes Ctrl+Z and Ctrl+S without applying history or Save Draft")
	actions.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	ui.call("_input", _key(KEY_Q, false))
	_check(not _q_open() and _points() == before, "focus loss cancels Q before key release can apply a selection")
	root.gui_release_focus()
	ui.call("_input", _key(KEY_Z, true, true))
	ui.call("_input", _key(KEY_Z, false, true))
	_check(_points().size() == before.size() - 1, "Ctrl+Z still undoes an authored point outside Q")
	ui.call("_input", _key(KEY_S, true, true))
	_check(not _popup_open(), "Ctrl+S is not intercepted as S popup")
	ui.call("_unhandled_input", _key(KEY_S, true, true))
	_check(status.text == "Save failed: no WIP library" and not _popup_open(), "Ctrl+S reaches actual Save Draft route with deliberately absent test library")
	var text := LineEdit.new()
	text.position = Vector2(8, 8)
	text.size = Vector2(160, 32)
	root.add_child(text)
	text.grab_focus()
	await process_frame
	before = _points()
	ui.call("_input", _key(KEY_Q))
	ui.call("_input", _key(KEY_S))
	for code in range(KEY_1, KEY_6 + 1):
		_check(not bool(actions.call("handle_input", _key(code))), "text entry retains number %d" % (code - KEY_1 + 1))
	_check(root.gui_get_focus_owner() == text and not _q_open() and not _popup_open() and _points() == before,
		"focused text retains Q/S and authored work")
	root.gui_release_focus()
	text.queue_free()
	await process_frame
	ui.call("_input", _key(KEY_S))
	actions.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not _popup_open() and _points() == before, "focus loss dismisses S popup without cancelling its authoring work")
	_open_q()
	ui.call("close_ui")
	_check(not _q_open() and not _popup_open() and not bool(ui.call("is_open")), "Forge close clears active quick surfaces")
	ui.call("_input", _key(KEY_Q, false))
	_check(not _q_open() and not _popup_open(), "late Q release after Forge close cannot reopen or select")


func _fresh(tool: StringName) -> void:
	actions.call("dismiss")
	ui.call("_set_retained_edit_mode", false)
	root.gui_release_focus()
	state = controller.call("start_new_draft", "Workspace Actions Verify") as Resource
	controller.call("select_tool_for_authoring", tool)
	controller.call("set_active_operation_mode", ADD)
	ui.call("_refresh_from_controller")


func _append_path(count: int) -> void:
	var points: Array[Vector3] = [Vector3(-0.18, 0, 0), Vector3(0, 0.035, 0), Vector3(0.18, 0, 0)]
	for index in count:
		controller.call("append_spline_line_point", points[index], Vector3.UP)


func _hover_workspace() -> void:
	root.gui_release_focus()
	var workspace := ui.get("workspace_view_container") as Control
	var motion := InputEventMouseMotion.new()
	motion.position = workspace.get_global_transform_with_canvas() * (workspace.size * 0.5)
	if DisplayServer.get_name() != "headless":
		if not screen_cursor_warped:
			saved_screen_cursor = DisplayServer.mouse_get_position()
			screen_cursor_warped = true
		root.warp_mouse(motion.position)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	_check(Rect2(Vector2.ZERO, workspace.size).has_point(workspace.get_local_mouse_position()), "real workspace hover established")


func _open_q() -> void:
	_hover_workspace()
	ui.call("_input", _key(KEY_Q))
	_check(_q_open() and _radial() != null, "Q input opens tool wheel")


func _choose_q(index: int) -> void:
	_open_q()
	var radial := _radial()
	if radial == null:
		return
	var direction := Vector2.from_angle(-PI * 0.5 + float(index) * PI * 0.5)
	_radial_pointer(radial, _radial_center(radial) + direction * float(radial.get("_outer_radius")) * 0.7)
	ui.call("_input", _key(KEY_Q, false))


func _choose_operation(add: bool) -> void:
	_open_q()
	var radial := _radial()
	if radial == null:
		return
	_radial_pointer(radial, _radial_center(radial) + (Vector2.LEFT if add else Vector2.RIGHT) * float(radial.get("_inner_radius")) * 0.6)
	ui.call("_input", _key(KEY_Q, false))


func _radial_pointer(radial: Control, local_position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = radial.get_global_transform_with_canvas() * local_position
	ui.call("_input", event)


func _press_shape_tool(tool: StringName) -> void:
	ui.call("_rebuild_v2_action_menus")
	var shape := ui.get("shape_menu_button") as MenuButton
	var submenu := shape.get_popup().get_node_or_null("ToolSubmenu") as PopupMenu
	if not _check(submenu != null, "Shape Tool submenu is available"):
		return
	var lookup: Dictionary = ui.get("menu_action_lookup") as Dictionary
	for index in submenu.item_count:
		var action_id := submenu.get_item_id(index)
		var entry: Dictionary = lookup.get(action_id, {}) as Dictionary
		if StringName(entry.get("action", &"")) == &"tool" and StringName(entry.get("value", &"")) == tool:
			submenu.id_pressed.emit(action_id)
			return
	_check(false, "requested ordinary tool exists in actual Shape Tool menu")


func _click_popup_button(button_name: String) -> void:
	await process_frame
	var popup := _popup()
	var button := _popup_button(button_name)
	if not _check(popup != null and button != null and popup.visible, button_name + " real popup button is available"):
		return
	var pointer := button.get_global_transform_with_canvas() * (button.size * 0.5)
	var click_evidence := {
		"button": button_name, "disabled": button.disabled,
		"popup_size": popup.size, "button_rect": button.get_global_rect(),
		"pointer_in_popup": pointer, "button_viewport_is_popup": button.get_viewport() == popup,
		"popup_embedded": popup.is_embedded(), "root_embeds_subwindows": root.gui_embed_subwindows,
		"gui_input_disabled": popup.gui_disable_input, "handle_input_locally": popup.handle_input_locally,
		"gui_mouse_button_events": [], "pressed_signals": 0,
	}
	button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			(click_evidence["gui_mouse_button_events"] as Array).append({
				"pressed": event.pressed, "position": event.position,
			})
	)
	button.pressed.connect(func() -> void:
		click_evidence["pressed_signals"] = int(click_evidence["pressed_signals"]) + 1
	)
	# Godot updates hover at the containing native Window, then forwards into
	# embedded popups. Direct popup.push_input skips that hover traversal even
	# though it can still deliver GUI button events, so it is not a real click.
	var input_window: Window = root if popup.is_embedded() else popup
	var screen_pointer := button.get_screen_transform() * (button.size * 0.5)
	var input_pointer := input_window.get_screen_transform().affine_inverse() * screen_pointer
	click_evidence["input_window_id"] = input_window.get_window_id()
	click_evidence["pointer_in_input_window"] = input_pointer
	if DisplayServer.get_name() != "headless":
		if not screen_cursor_warped:
			saved_screen_cursor = DisplayServer.mouse_get_position()
			screen_cursor_warped = true
		input_window.warp_mouse(input_pointer)
		await process_frame
		if not _check(is_instance_valid(popup) and popup.visible, "popup remains open while real cursor enters " + button_name):
			return
	var motion := InputEventMouseMotion.new()
	motion.position = input_pointer
	motion.global_position = input_pointer
	motion.window_id = input_window.get_window_id()
	input_window.push_input(motion, true)
	if DisplayServer.get_name() != "headless":
		input_window.update_mouse_cursor_state()
	var hovered := popup.gui_get_hovered_control()
	click_evidence["hovered_after_motion"] = String(hovered.name) if hovered != null else ""
	for pressed: bool in [true, false]:
		if not is_instance_valid(popup):
			break
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = input_pointer
		click.global_position = input_pointer
		click.window_id = input_window.get_window_id()
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		input_window.push_input(click, true)
		if pressed and is_instance_valid(button):
			click_evidence["draw_mode_after_press"] = button.get_draw_mode()
	click_evidence["popup_open_after_click"] = _popup_open()
	if not evidence.has("popup_clicks"):
		evidence["popup_clicks"] = []
	(evidence["popup_clicks"] as Array).append(click_evidence)


func _click_outside_popup() -> void:
	await process_frame
	var popup := _popup()
	if not _check(popup != null and popup.is_embedded(), "outside-click fixture owns an embedded popup"):
		return
	# Use the blank root margin, outside both the popup and the authoring viewport.
	var pointer := Vector2(2, 2)
	if DisplayServer.get_name() != "headless":
		root.warp_mouse(pointer)
		await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = pointer
	motion.global_position = pointer
	motion.window_id = root.get_window_id()
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = pointer
		click.global_position = pointer
		click.window_id = root.get_window_id()
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(click, true)
	await process_frame
	evidence["outside_dismissal"] = {"route": "root viewport mouse press and release", "position": pointer,
		"popup_open_after_release": _popup_open()}


func _popup_button(button_name: String) -> Button:
	var popup := _popup()
	return popup.find_child(button_name, true, false) as Button if popup != null else null


func _popup() -> PopupPanel:
	var popup := actions.get("context_popup") as PopupPanel
	return popup if is_instance_valid(popup) else null


func _popup_open() -> bool:
	return bool(actions.call("is_popup_open"))


func _radial() -> Control:
	return actions.get("radial") as Control


func _radial_center(radial: Control) -> Vector2:
	return radial.get("_center") as Vector2


func _q_open() -> bool:
	return bool(actions.get("radial_active"))


func _tool() -> StringName:
	return StringName(state.get("active_tool_id"))


func _operation() -> StringName:
	return StringName(state.get("active_operation_mode"))


func _points() -> PackedVector3Array:
	return (state.get("spline_line_points") as PackedVector3Array).duplicate()


func _user_body_count() -> int:
	return int(state.call("get_user_material_body_count"))


func _pending_body_count() -> int:
	return int(state.call("get_pending_material_body_count"))


func _matches(action: StringName, event: InputEvent) -> bool:
	return bool(keys.call("event_matches_action", action, event))


func _key(code: int, pressed: bool = true, control: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.ctrl_pressed = control
	return event


func _capture(suffix: String) -> void:
	var requested := OS.get_environment("THE_WILL_WORKSPACE_ACTIONS_SCREENSHOT").strip_edges()
	if requested.is_empty() or DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var path := requested.get_basename() + "_" + suffix + ".png"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_check(root.get_texture().get_image().save_png(path) == OK, "rendered " + suffix + " capture saved")


func _check(condition: bool, label: String) -> bool:
	checks.append({"label": label, "passed": condition})
	if not condition:
		failures += 1
		printerr("FAIL: ", label)
	return condition


func _finish() -> void:
	if screen_cursor_warped:
		DisplayServer.warp_mouse(saved_screen_cursor - DisplayServer.window_get_position(root.get_window_id()))
		_check(DisplayServer.mouse_get_position().distance_to(saved_screen_cursor) <= 1.0, "rendered verifier restores original OS cursor")
	ui.call("close_ui")
	ui.queue_free()
	controller.queue_free()
	await process_frame
	DirAccess.make_dir_recursive_absolute(REPORT.get_base_dir())
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"ok": failures == 0, "passed": checks.size() - failures,
			"failed": failures, "checks": checks, "evidence": evidence}, "\t"))
		file.close()
	else:
		_check(false, "report file opens for writing")
	print("FORGE_WORKSPACE_ACTIONS: ", JSON.stringify({"ok": failures == 0,
		"passed": checks.size() - failures, "failed": failures, "report": REPORT}))
	quit(0 if failures == 0 else 1)
