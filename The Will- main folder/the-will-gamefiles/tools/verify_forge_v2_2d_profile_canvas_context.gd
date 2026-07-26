extends SceneTree

const CraftingBenchUIV2Script = preload(
	"res://runtime/forge_v2/crafting_bench_ui_v2.gd"
)
const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeV2StageControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const CraftingBenchUIV2Scene = preload(
	"res://scenes/ui_v2/crafting_bench_ui_v2.tscn"
)
const UiWindowLayerPolicyScript = preload(
	"res://runtime/ui/ui_window_layer_policy.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_2d_profile_canvas_context_2026-07-26.txt"
)
const EPSILON := 0.00001

var result_lines: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())

	var controller: Node = ForgeV2StageControllerScript.new()
	get_root().add_child(controller)
	await process_frame
	controller.call("reset_active_basic_profile_builder")

	var ui: CanvasLayer = CraftingBenchUIV2Scene.instantiate() as CanvasLayer
	get_root().add_child(ui)
	await process_frame
	ui.call("open_for", null, controller, "Canvas Context Verify", null)
	ui.call("_open_profile_builder_popup")
	ui.call("_ensure_settings_popup")
	ui.call("_ensure_keybindings_popup")
	ui.call("_ensure_profile_saved_profiles_popup")
	await process_frame
	var profile_workspace := ui.get("profile_builder_popup") as PopupPanel
	var settings_workspace := ui.get("settings_popup") as PopupPanel
	var keybindings_workspace := ui.get("keybindings_popup") as PopupPanel
	var saved_profiles_workspace := ui.get(
		"profile_saved_profiles_popup"
	) as PopupPanel
	var context_probe_actions: Array[Dictionary] = [{
		"label": "Probe",
		"callback": Callable(ui, "_hide_profile_canvas_context_menu"),
	}]
	var canvas_context_probe := ui.call(
		"_build_profile_canvas_context_panel",
		context_probe_actions
	) as PopupPanel
	var saved_context_probe := ui.call(
		"_build_saved_profile_context_panel"
	) as PopupPanel
	if not _check(
		profile_workspace != null
		and settings_workspace != null
		and profile_workspace.visible
		and _is_persistent_major_workspace(profile_workspace)
		and _is_persistent_major_workspace(settings_workspace),
		"major Forge V2 workspaces retained focus-loss auto-dismiss"
	):
		return
	if not _check(
		_is_owned_ephemeral_popup(
			keybindings_workspace,
			settings_workspace
		)
		and _is_owned_ephemeral_popup(
			saved_profiles_workspace,
			profile_workspace
		),
		"Forge V2 sub-workspaces did not retain their declared next-of-kin"
	):
		return
	if not _check(
		canvas_context_probe != null
		and saved_context_probe != null
		and _is_ephemeral_popup(canvas_context_probe)
		and _is_ephemeral_popup(saved_context_probe),
		"temporary RMB context popup lifetime was changed"
	):
		return
	canvas_context_probe.free()
	saved_context_probe.free()
	if not _verify_visual_input_surface_policy():
		return
	if not _check(
		not ui.has_method("_on_profile_canvas_context_window_input")
		and not ui.has_method(
			"_on_saved_profile_context_window_input"
		),
		"context popups still forward input into a covered parent surface"
	):
		return
	var preview: Control = ui.get("profile_builder_preview") as Control
	if not _check(preview != null, "real Forge V2 profile preview was not constructed"):
		return
	# Keep geometry deterministic after the real owned workspace has been opened.
	preview.size = Vector2(420.0, 420.0)
	ui.call("_refresh_profile_builder_popup")
	await process_frame

	var builder_settings := _builder_settings(controller)
	if not _check(
		not builder_settings.is_empty()
		and bool(builder_settings.get("is_active", false))
		and StringName(builder_settings.get("family", StringName()))
		== ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC,
		"real profile UI did not expose an active Basic builder"
	):
		return
	var ui_basic_settings: Dictionary = ui.call(
		"_get_active_basic_profile_builder_settings"
	) as Dictionary
	if not _check(
		not ui_basic_settings.is_empty()
		and bool(preview.get("canvas_context_enabled")),
		"Basic-only canvas context gate did not enable for the Basic builder"
	):
		return
	if not await _verify_saved_profile_context_hierarchy(
		ui,
		profile_workspace,
		saved_profiles_workspace
	):
		return

	var initial_points: PackedVector2Array = builder_settings.get(
		"control_points_2d_meters",
		PackedVector2Array()
	)
	var initial_metadata: Array = builder_settings.get(
		"corner_metadata",
		[]
	) as Array
	var initial_ids := _corner_ids(initial_metadata)
	if not _check(
		initial_points.size() == 4
		and initial_metadata.size() == 4
		and _ids_are_unique(initial_ids),
		"default Basic builder did not expose four unique stable corner IDs"
	):
		return

	if not _check(
		_labels_match(
			_action_labels(ui, &"segment", initial_ids[0]),
			PackedStringArray(["Add Point"])
		),
		"unfilleted Basic segment did not offer exactly Add Point"
	):
		return
	if not _check(
		_labels_match(
			_action_labels(ui, &"control_point", initial_ids[0]),
			PackedStringArray(["Remove", "Fillet"])
		),
		"four-point unfilleted Basic corner did not offer Remove and Fillet"
	):
		return
	if not _check(
		_action_labels(ui, &"fillet", initial_ids[0]).is_empty(),
		"unfilleted Basic corner unexpectedly exposed fillet-arc actions"
	):
		return

	if not await _verify_target_precedence():
		return

	var draw_scale := float(preview.call("_calculate_view_scale"))
	var segment_start_index := 1
	var segment_end_index := 2
	var insertion_screen := preview.call(
		"_profile_to_screen",
		(initial_points[segment_start_index] + initial_points[segment_end_index])
		* 0.5,
		draw_scale
	) as Vector2
	var insertion_target: Dictionary = preview.call(
		"get_canvas_context_target",
		insertion_screen
	) as Dictionary
	if not _check(
		StringName(insertion_target.get("target_kind", StringName()))
		== &"segment"
		and int(insertion_target.get("target_index", -1))
		== segment_start_index
		and StringName(insertion_target.get("target_id", StringName()))
		== initial_ids[segment_start_index],
		"real Basic preview did not resolve the requested insertion segment"
	):
		return
	var insertion_position: Vector2 = insertion_target.get(
		"target_position_meters",
		Vector2(INF, INF)
	) as Vector2
	var expected_midpoint := (
		initial_points[segment_start_index] + initial_points[segment_end_index]
	) * 0.5
	if not _check(
		insertion_position.distance_to(expected_midpoint) <= EPSILON,
		"segment context target did not retain its projected insertion position"
	):
		return

	var profile_workspace_instance_id := profile_workspace.get_instance_id()
	ui.call(
		"_on_profile_canvas_context_requested",
		StringName(insertion_target.get("target_kind", StringName())),
		int(insertion_target.get("target_index", -1)),
		StringName(insertion_target.get("target_id", StringName())),
		insertion_position
	)
	await process_frame
	var first_canvas_context := ui.get(
		"profile_canvas_context_panel"
	) as PopupPanel
	if not _check(
		_is_owned_ephemeral_popup(
			first_canvas_context,
			profile_workspace
		)
		and first_canvas_context.visible,
		"canvas RMB context was not owned by its visible Profiles workspace"
	):
		return
	var first_canvas_context_instance_id := (
		first_canvas_context.get_instance_id()
	)
	ui.call("_on_profile_canvas_add_point_pressed")
	await process_frame
	if not _check(
		ui.get("profile_canvas_context_panel") == null
		and not is_instance_valid(first_canvas_context)
		and is_instance_valid(profile_workspace)
		and profile_workspace.get_instance_id()
		== profile_workspace_instance_id
		and profile_workspace.visible,
		"Add Point did not dismiss only its RMB child and restore Profiles"
	):
		return
	builder_settings = _builder_settings(controller)
	var points_after_insert: PackedVector2Array = builder_settings.get(
		"control_points_2d_meters",
		PackedVector2Array()
	)
	var metadata_after_insert: Array = builder_settings.get(
		"corner_metadata",
		[]
	) as Array
	var ids_after_insert := _corner_ids(metadata_after_insert)
	var inserted_id := _find_added_id(ids_after_insert, initial_ids)
	var expected_ids_after_insert: Array[StringName] = [
		initial_ids[0],
		initial_ids[1],
		inserted_id,
		initial_ids[2],
		initial_ids[3],
	]
	if not _check(
		inserted_id != StringName()
		and points_after_insert.size() == 5
		and _ids_are_unique(ids_after_insert)
		and _ids_match(ids_after_insert, expected_ids_after_insert)
		and points_after_insert[2].distance_to(insertion_position) <= EPSILON
		and not (metadata_after_insert[2] as Dictionary).has("radius_meters"),
		"Add Point did not insert a new stable-ID corner after its target segment"
	):
		return

	# A second RMB request must work immediately after the action. No synthetic
	# LMB/focus confirmation is inserted between these two production calls.
	var next_context_position := (
		points_after_insert[0] + points_after_insert[1]
	) * 0.5
	ui.call(
		"_on_profile_canvas_context_requested",
		&"segment",
		0,
		ids_after_insert[0],
		next_context_position
	)
	await process_frame
	var second_canvas_context := ui.get(
		"profile_canvas_context_panel"
	) as PopupPanel
	if not _check(
		_is_owned_ephemeral_popup(
			second_canvas_context,
			profile_workspace
		)
		and second_canvas_context.visible
		and second_canvas_context.get_instance_id()
		!= first_canvas_context_instance_id
		and profile_workspace.visible,
		"RMB -> Add Point -> RMB required an intervening LMB focus repair"
	):
		return
	ui.call("_hide_profile_canvas_context_menu")
	await process_frame
	if not _check(
		ui.get("profile_canvas_context_panel") == null
		and not is_instance_valid(second_canvas_context)
		and profile_workspace.visible,
		"closing the second canvas RMB context did not return to Profiles"
	):
		return

	var fillet_corner_id: StringName = initial_ids[0]
	ui.set("profile_canvas_context_target_id", fillet_corner_id)
	ui.call("_on_profile_canvas_add_fillet_pressed")
	var fillet_settings: Dictionary = controller.call(
		"get_active_basic_corner_fillet_settings",
		fillet_corner_id
	) as Dictionary
	if not _check(
		bool(fillet_settings.get("has_fillet", false))
		and is_equal_approx(
			float(fillet_settings.get("radius_meters", 0.0)),
			0.01
		)
		and is_equal_approx(
			float(fillet_settings.get("default_radius_meters", 0.0)),
			0.01
		),
		"Fillet action did not create the required 0.01 m default fillet"
	):
		return
	builder_settings = _builder_settings(controller)
	if not _check(
		_ids_match(
			_corner_ids(builder_settings.get("corner_metadata", []) as Array),
			ids_after_insert
		),
		"adding a fillet changed stable corner IDs"
	):
		return

	if not _check(
		_labels_match(
			_action_labels(ui, &"control_point", fillet_corner_id),
			PackedStringArray(["Remove"])
		),
		"filleted four-plus-point control corner did not retain only Remove"
	):
		return
	if not _check(
		_labels_match(
			_action_labels(ui, &"fillet", fillet_corner_id),
			PackedStringArray(["Remove Fillet", "Fillet Size"])
		),
		"fillet arc did not offer Remove Fillet and Fillet Size"
	):
		return
	if not _check(
		_labels_match(
			_action_labels(ui, &"control_point", initial_ids[1]),
			PackedStringArray(["Remove", "Fillet"])
		),
		"unfilleted four-plus-point corner lost its Remove or Fillet action"
	):
		return

	ui.call("_refresh_profile_builder_popup")
	var fillet_overlap_error := _verify_real_fillet_beats_segment(
		preview,
		_builder_settings(controller),
		fillet_corner_id
	)
	if not _check(
		fillet_overlap_error.is_empty(),
		"real fillet/segment target overlap: %s" % fillet_overlap_error
	):
		return

	if not _check(
		is_equal_approx(
			float(fillet_settings.get("minimum_radius_meters", 0.0)),
			0.001
		)
		and is_equal_approx(
			float(fillet_settings.get("maximum_radius_meters", 0.0)),
			0.3
		),
		"Fillet Size contract did not report the 0.001-0.3 m bounds"
	):
		return
	if not _check(
		bool(controller.call(
			"set_active_basic_corner_fillet_radius",
			fillet_corner_id,
			-1.0
		)),
		"Fillet Size setter rejected a lower-bound clamp request"
	):
		return
	fillet_settings = controller.call(
		"get_active_basic_corner_fillet_settings",
		fillet_corner_id
	) as Dictionary
	if not _check(
		is_equal_approx(
			float(fillet_settings.get("radius_meters", 0.0)),
			0.001
		),
		"Fillet Size setter did not clamp to 0.001 m"
	):
		return
	if not _check(
		bool(controller.call(
			"set_active_basic_corner_fillet_radius",
			fillet_corner_id,
			1.0
		)),
		"Fillet Size setter rejected an upper-bound clamp request"
	):
		return
	fillet_settings = controller.call(
		"get_active_basic_corner_fillet_settings",
		fillet_corner_id
	) as Dictionary
	if not _check(
		is_equal_approx(
			float(fillet_settings.get("radius_meters", 0.0)),
			0.3
		),
		"Fillet Size setter did not clamp to 0.3 m"
	):
		return
	if not _check(
		bool(controller.call(
			"set_active_basic_corner_fillet_radius",
			fillet_corner_id,
			0.02
		)),
		"could not establish the pre-dialog fillet radius"
	):
		return

	fillet_settings = controller.call(
		"get_active_basic_corner_fillet_settings",
		fillet_corner_id
	) as Dictionary
	var fillet_popup: PopupPanel = ui.call(
		"_build_profile_fillet_popup",
		fillet_settings
	) as PopupPanel
	if not _check(
		fillet_popup != null,
		"Fillet Size popup could not be constructed headlessly"
	):
		return
	if not _check(
		UiWindowLayerPolicyScript.attach_owned_popup(
			profile_workspace,
			fillet_popup
		)
		and _is_owned_ephemeral_popup(
			fillet_popup,
			profile_workspace
		),
		"Fillet Size popup did not retain Profiles as its next-of-kin"
	):
		fillet_popup.free()
		return
	ui.set("profile_fillet_popup", fillet_popup)
	ui.set("profile_fillet_pending_corner_id", fillet_corner_id)
	ui.set("profile_fillet_restore_profile_builder", false)
	var fillet_spin_box: SpinBox = ui.get(
		"profile_fillet_spin_box"
	) as SpinBox
	if not _check(
		fillet_spin_box != null
		and is_equal_approx(fillet_spin_box.min_value, 0.001)
		and is_equal_approx(fillet_spin_box.max_value, 0.3)
		and is_equal_approx(fillet_spin_box.step, 0.001)
		and not fillet_spin_box.allow_lesser
		and not fillet_spin_box.allow_greater,
		"Fillet Size input did not enforce its production bounds and step"
	):
		return
	var fillet_line_edit := fillet_spin_box.get_line_edit()
	fillet_spin_box.value = 0.123
	fillet_line_edit.text = "0.077"
	fillet_settings = controller.call(
		"get_active_basic_corner_fillet_settings",
		fillet_corner_id
	) as Dictionary
	if not _check(
		is_equal_approx(
			float(fillet_settings.get("radius_meters", 0.0)),
			0.02
		),
		"editing Fillet Size mutated state before confirmation"
	):
		return
	var confirmed_radius := 0.077
	ui.call("_request_profile_fillet_size_apply")
	await process_frame
	fillet_settings = controller.call(
		"get_active_basic_corner_fillet_settings",
		fillet_corner_id
	) as Dictionary
	if not _check(
		is_equal_approx(
			float(fillet_settings.get("radius_meters", 0.0)),
			confirmed_radius
		)
		and ui.get("profile_fillet_popup") == null
		and ui.get("profile_fillet_spin_box") == null,
		"Fillet Size Apply did not commit the unsubmitted typed value and close the editor"
	):
		return
	await process_frame
	builder_settings = _builder_settings(controller)
	if not _check(
		_ids_match(
			_corner_ids(builder_settings.get("corner_metadata", []) as Array),
			ids_after_insert
		),
		"fillet radius edits changed stable corner IDs"
	):
		return

	if not _check(
		bool(controller.call(
			"remove_active_basic_control_point",
			inserted_id
		)),
		"could not return the Basic profile from five to four points"
	):
		return
	builder_settings = _builder_settings(controller)
	var four_point_ids := _corner_ids(
		builder_settings.get("corner_metadata", []) as Array
	)
	if not _check(
		_ids_match(four_point_ids, initial_ids)
		and _labels_match(
			_action_labels(ui, &"control_point", initial_ids[1]),
			PackedStringArray(["Remove", "Fillet"])
		),
		"four-point menu threshold or stable IDs were not retained"
	):
		return
	if not _check(
		bool(controller.call(
			"remove_active_basic_control_point",
			initial_ids[2]
		)),
		"could not reduce the Basic profile to its three-point minimum"
	):
		return
	builder_settings = _builder_settings(controller)
	var three_point_ids := _corner_ids(
		builder_settings.get("corner_metadata", []) as Array
	)
	var expected_three_point_ids: Array[StringName] = [
		initial_ids[0],
		initial_ids[1],
		initial_ids[3],
	]
	if not _check(
		_ids_match(three_point_ids, expected_three_point_ids)
		and _labels_match(
			_action_labels(ui, &"control_point", initial_ids[1]),
			PackedStringArray(["Fillet"])
		)
		and _action_labels(
			ui,
			&"control_point",
			fillet_corner_id
		).is_empty()
		and _labels_match(
			_action_labels(ui, &"fillet", fillet_corner_id),
			PackedStringArray(["Remove Fillet", "Fillet Size"])
		),
		"three-point filleted/unfilleted menu availability was incorrect"
	):
		return
	if not _check(
		not bool(controller.call(
			"remove_active_basic_control_point",
			initial_ids[1]
		))
		and _ids_match(
			_corner_ids(
				_builder_settings(controller).get(
					"corner_metadata",
					[]
				) as Array
			),
			expected_three_point_ids
		),
		"three-point minimum allowed removal or changed stable IDs"
	):
		return

	ui.call("_select_profile_builder_handle_builder")
	await process_frame
	var handles_builder_settings := _builder_settings(controller)
	var handles_probe_position := preview.size * 0.5
	if not _check(
		StringName(handles_builder_settings.get("family", StringName()))
		== ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_HANDLE
		and (
			ui.call("_get_active_basic_profile_builder_settings")
			as Dictionary
		).is_empty()
		and not bool(preview.get("canvas_context_enabled"))
		and (
			preview.call(
				"get_canvas_context_target",
				handles_probe_position
			) as Dictionary
		).is_empty()
		and _action_labels(
			ui,
			&"segment",
			initial_ids[0]
		).is_empty()
		and _action_labels(
			ui,
			&"control_point",
			initial_ids[0]
		).is_empty()
		and _action_labels(
			ui,
			&"fillet",
			initial_ids[0]
		).is_empty(),
		"Handles did not stay outside the Basic canvas-context contract"
	):
		return
	if not _check(
		StringName(controller.call(
			"insert_active_basic_control_point_on_segment",
			initial_ids[0],
			Vector2.ZERO
		)) == StringName()
		and not bool(controller.call(
			"add_active_basic_corner_fillet",
			initial_ids[0]
		))
		and not bool(controller.call(
			"set_active_basic_corner_fillet_radius",
			initial_ids[0],
			0.05
		)),
		"Basic topology methods remained active while Handles was selected"
	):
		return

	result_lines.append("ok=true")
	result_lines.append("major_workspace_auto_dismiss=false")
	result_lines.append("rmb_context_auto_dismiss=true")
	result_lines.append("owned_window_hierarchy=true")
	result_lines.append("visual_top_layer_input_authority=true")
	result_lines.append("covered_popup_input_forwarding=false")
	result_lines.append("next_of_kin_restoration=headless_structural")
	result_lines.append("back_to_back_canvas_context=true")
	result_lines.append("back_to_back_saved_profile_context=true")
	result_lines.append("basic_only_context_gate=true")
	result_lines.append("target_precedence=control_point>fillet>segment")
	result_lines.append("segment_insertion_target=true")
	result_lines.append("menu_actions_3_and_4_plus=true")
	result_lines.append("default_fillet_radius_meters=0.01")
	result_lines.append("fillet_size_bounds_meters=0.001..0.3")
	result_lines.append("fillet_size_confirm_only=true")
	result_lines.append("stable_corner_ids=true")
	result_lines.append("handles_excluded=true")
	_write_results()
	quit(0)


func _is_persistent_major_workspace(window: Window) -> bool:
	return (
		window != null
		and not window.popup_window
		and not window.popup_wm_hint
		and window.transient
		and not window.transient_to_focused
		and not window.exclusive
	)


func _is_ephemeral_popup(window: Window) -> bool:
	return (
		window != null
		and window.popup_window
		and window.popup_wm_hint
		and window.transient
		and not window.transient_to_focused
		and not window.exclusive
	)


func _is_owned_ephemeral_popup(
	window: Window,
	expected_owner: Window
) -> bool:
	return (
		_is_ephemeral_popup(window)
		and expected_owner != null
		and window.get_parent() == expected_owner
	)


func _verify_visual_input_surface_policy() -> bool:
	var surface := PanelContainer.new()
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.mouse_force_pass_scroll_events = true
	UiWindowLayerPolicyScript.configure_visual_input_surface(surface)
	var policy_applied := (
		surface.mouse_filter == Control.MOUSE_FILTER_STOP
		and not surface.mouse_force_pass_scroll_events
	)
	surface.free()
	return _check(
		policy_applied,
		"top visual input surface still allowed pointer/scroll click-through"
	)


func _verify_saved_profile_context_hierarchy(
	ui: CanvasLayer,
	profile_workspace: PopupPanel,
	saved_profiles_workspace: PopupPanel
) -> bool:
	ui.call("_open_profile_saved_profiles_popup")
	await process_frame
	if not _check(
		_is_owned_ephemeral_popup(
			saved_profiles_workspace,
			profile_workspace
		)
		and saved_profiles_workspace.visible
		and profile_workspace.visible,
		"Saved Profiles did not open as a child of Profiles"
	):
		return false

	var saved_workspace_instance_id := (
		saved_profiles_workspace.get_instance_id()
	)
	var profile_workspace_instance_id := profile_workspace.get_instance_id()
	var probe_profile_id := &"verify_saved_context_owner"
	ui.call("_open_saved_profile_context_menu", probe_profile_id)
	await process_frame
	var first_saved_context := ui.get(
		"profile_saved_profiles_context_panel"
	) as PopupPanel
	if not _check(
		_is_owned_ephemeral_popup(
			first_saved_context,
			saved_profiles_workspace
		)
		and first_saved_context.visible,
		"saved-profile RMB context was not owned by Saved Profiles"
	):
		return false
	var first_context_instance_id := first_saved_context.get_instance_id()

	# Rename is a real saved-item action. The probe ID deliberately has no saved
	# record, so this exercises dismissal/return without mutating user data.
	ui.call("_on_saved_profile_context_rename_pressed")
	await process_frame
	if not _check(
		ui.get("profile_saved_profiles_context_panel") == null
		and not is_instance_valid(first_saved_context)
		and is_instance_valid(saved_profiles_workspace)
		and saved_profiles_workspace.get_instance_id()
		== saved_workspace_instance_id
		and saved_profiles_workspace.visible
		and is_instance_valid(profile_workspace)
		and profile_workspace.get_instance_id()
		== profile_workspace_instance_id
		and profile_workspace.visible,
		"saved-item action did not return to its existing Saved Profiles parent"
	):
		return false

	ui.call("_open_saved_profile_context_menu", probe_profile_id)
	await process_frame
	var second_saved_context := ui.get(
		"profile_saved_profiles_context_panel"
	) as PopupPanel
	if not _check(
		_is_owned_ephemeral_popup(
			second_saved_context,
			saved_profiles_workspace
		)
		and second_saved_context.visible
		and second_saved_context.get_instance_id()
		!= first_context_instance_id,
		"saved-item RMB context required an intervening focus-repair click"
	):
		return false

	ui.call("_hide_saved_profile_context_menu")
	await process_frame
	if not _check(
		ui.get("profile_saved_profiles_context_panel") == null
		and not is_instance_valid(second_saved_context)
		and saved_profiles_workspace.visible
		and profile_workspace.visible,
		"closing saved-item RMB context did not return to Saved Profiles"
	):
		return false
	ui.call("_close_profile_saved_profiles_popup")
	await process_frame
	return _check(
		not saved_profiles_workspace.visible
		and profile_workspace.visible,
		"closing Saved Profiles affected its persistent Profiles ancestor"
	)


func _verify_target_precedence() -> bool:
	var preview: Control = (
		CraftingBenchUIV2Script.ProfileBuilderPreviewControl.new()
	)
	preview.name = "CanvasContextPrecedencePreview"
	preview.size = Vector2(400.0, 400.0)
	get_root().add_child(preview)
	var points := PackedVector2Array([
		Vector2(-0.5, -0.5),
		Vector2(0.5, -0.5),
		Vector2(0.5, 0.5),
		Vector2(-0.5, 0.5),
	])
	var metadata: Array = [
		{"corner_id": &"precedence_corner_0"},
		{"corner_id": &"precedence_corner_1"},
		{"corner_id": &"precedence_corner_2"},
		{"corner_id": &"precedence_corner_3"},
	]
	var fillet_results: Array = [{
		"corner_id": &"precedence_corner_0",
		"index": 0,
		"arc_points": PackedVector2Array([
			points[0],
			points[0] + Vector2(0.45, 0.0),
		]),
	}]
	preview.call(
		"set_profile_geometry",
		points,
		points,
		true,
		Vector2.ZERO,
		metadata,
		fillet_results
	)
	var draw_scale := float(preview.call("_calculate_view_scale"))
	var all_three_screen: Vector2 = preview.call(
		"_profile_to_screen",
		points[0],
		draw_scale
	) as Vector2
	preview.call("configure_canvas_context", false)
	if not _check(
		(preview.call(
			"get_canvas_context_target",
			all_three_screen
		) as Dictionary).is_empty(),
		"disabled canvas context still resolved a target"
	):
		return false
	preview.call("configure_canvas_context", true)
	var point_candidate := int(preview.call(
		"_find_nearest_control_point",
		all_three_screen
	))
	var fillet_candidate: Dictionary = preview.call(
		"_find_nearest_fillet_arc",
		all_three_screen
	) as Dictionary
	var segment_candidate: Dictionary = preview.call(
		"_find_nearest_control_segment",
		all_three_screen
	) as Dictionary
	var resolved_target: Dictionary = preview.call(
		"get_canvas_context_target",
		all_three_screen
	) as Dictionary
	if not _check(
		point_candidate == 0
		and not fillet_candidate.is_empty()
		and not segment_candidate.is_empty()
		and StringName(resolved_target.get("target_kind", StringName()))
		== &"control_point"
		and StringName(resolved_target.get("target_id", StringName()))
		== &"precedence_corner_0",
		"control point did not win an exact point/fillet/segment overlap"
	):
		return false

	var fillet_segment_position := points[0] + Vector2(0.25, 0.0)
	var fillet_segment_screen: Vector2 = preview.call(
		"_profile_to_screen",
		fillet_segment_position,
		draw_scale
	) as Vector2
	point_candidate = int(preview.call(
		"_find_nearest_control_point",
		fillet_segment_screen
	))
	fillet_candidate = preview.call(
		"_find_nearest_fillet_arc",
		fillet_segment_screen
	) as Dictionary
	segment_candidate = preview.call(
		"_find_nearest_control_segment",
		fillet_segment_screen
	) as Dictionary
	resolved_target = preview.call(
		"get_canvas_context_target",
		fillet_segment_screen
	) as Dictionary
	if not _check(
		point_candidate < 0
		and not fillet_candidate.is_empty()
		and not segment_candidate.is_empty()
		and StringName(resolved_target.get("target_kind", StringName()))
		== &"fillet"
		and StringName(resolved_target.get("target_id", StringName()))
		== &"precedence_corner_0",
		"fillet arc did not win a fillet/segment overlap"
	):
		return false

	var segment_only_position := Vector2(0.5, 0.0)
	var segment_only_screen: Vector2 = preview.call(
		"_profile_to_screen",
		segment_only_position,
		draw_scale
	) as Vector2
	resolved_target = preview.call(
		"get_canvas_context_target",
		segment_only_screen
	) as Dictionary
	if not _check(
		StringName(resolved_target.get("target_kind", StringName()))
		== &"segment"
		and int(resolved_target.get("target_index", -1)) == 1
		and StringName(resolved_target.get("target_id", StringName()))
		== &"precedence_corner_1",
		"segment-only target did not resolve to its stable start-corner ID"
	):
		return false
	preview.queue_free()
	await process_frame
	return true


func _verify_real_fillet_beats_segment(
	preview: Control,
	builder_settings: Dictionary,
	corner_id: StringName
) -> String:
	var corner_result := _find_corner_result(
		builder_settings.get("fillet_corner_results", []) as Array,
		corner_id
	)
	if corner_result.is_empty():
		return "production builder did not publish the fillet corner result"
	var arc_points: PackedVector2Array = corner_result.get(
		"arc_points",
		PackedVector2Array()
	)
	if arc_points.size() < 2:
		return "production fillet did not publish a selectable arc"
	var draw_scale := float(preview.call("_calculate_view_scale"))
	var candidate_indices: Array[int] = [0, arc_points.size() - 1]
	for arc_index: int in candidate_indices:
		var screen_position: Vector2 = preview.call(
			"_profile_to_screen",
			arc_points[arc_index],
			draw_scale
		) as Vector2
		if int(preview.call(
			"_find_nearest_control_point",
			screen_position
		)) >= 0:
			continue
		var fillet_candidate: Dictionary = preview.call(
			"_find_nearest_fillet_arc",
			screen_position
		) as Dictionary
		var segment_candidate: Dictionary = preview.call(
			"_find_nearest_control_segment",
			screen_position
		) as Dictionary
		var resolved_target: Dictionary = preview.call(
			"get_canvas_context_target",
			screen_position
		) as Dictionary
		if (
			StringName(fillet_candidate.get("target_id", StringName()))
			== corner_id
			and not segment_candidate.is_empty()
			and StringName(resolved_target.get(
				"target_kind",
				StringName()
			)) == &"fillet"
			and StringName(resolved_target.get(
				"target_id",
				StringName()
			)) == corner_id
		):
			return ""
	return "no arc endpoint proved fillet precedence over its raw segment"


func _builder_settings(controller: Node) -> Dictionary:
	var summary: Dictionary = controller.call("get_status_summary") as Dictionary
	var profile_settings: Dictionary = summary.get(
		"active_profile_settings",
		{}
	) as Dictionary
	return profile_settings.get("profile_builder", {}) as Dictionary


func _corner_ids(metadata_array: Array) -> Array[StringName]:
	var ids: Array[StringName] = []
	for metadata_variant: Variant in metadata_array:
		if not metadata_variant is Dictionary:
			ids.append(StringName())
			continue
		var metadata := metadata_variant as Dictionary
		ids.append(StringName(metadata.get("corner_id", StringName())))
	return ids


func _ids_are_unique(ids: Array[StringName]) -> bool:
	var used_ids: Dictionary = {}
	for corner_id: StringName in ids:
		if corner_id == StringName() or used_ids.has(corner_id):
			return false
		used_ids[corner_id] = true
	return true


func _ids_match(
	first_ids: Array[StringName],
	second_ids: Array[StringName]
) -> bool:
	if first_ids.size() != second_ids.size():
		return false
	for id_index in range(first_ids.size()):
		if first_ids[id_index] != second_ids[id_index]:
			return false
	return true


func _find_added_id(
	current_ids: Array[StringName],
	previous_ids: Array[StringName]
) -> StringName:
	for corner_id: StringName in current_ids:
		if not previous_ids.has(corner_id):
			return corner_id
	return StringName()


func _action_labels(
	ui: CanvasLayer,
	target_kind: StringName,
	target_id: StringName
) -> PackedStringArray:
	var labels := PackedStringArray()
	var actions: Array = ui.call(
		"_build_profile_canvas_context_actions",
		target_kind,
		target_id
	) as Array
	for action_variant: Variant in actions:
		if action_variant is Dictionary:
			labels.append(String((action_variant as Dictionary).get(
				"label",
				""
			)))
	return labels


func _labels_match(
	actual_labels: PackedStringArray,
	expected_labels: PackedStringArray
) -> bool:
	if actual_labels.size() != expected_labels.size():
		return false
	for label_index in range(actual_labels.size()):
		if actual_labels[label_index] != expected_labels[label_index]:
			return false
	return true


func _find_corner_result(
	corner_results: Array,
	corner_id: StringName
) -> Dictionary:
	for result_variant: Variant in corner_results:
		if not result_variant is Dictionary:
			continue
		var corner_result := result_variant as Dictionary
		if (
			StringName(corner_result.get("corner_id", StringName()))
			== corner_id
		):
			return corner_result
	return {}


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	result_lines.append("ok=false")
	result_lines.append("error=%s" % message)
	_write_results()
	push_error(message)
	quit(1)


func _write_results() -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(result_lines))
		file.close()
