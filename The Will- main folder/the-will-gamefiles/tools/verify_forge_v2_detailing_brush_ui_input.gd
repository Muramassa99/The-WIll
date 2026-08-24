extends SceneTree

const CraftingBenchUIV2Scene = preload(
	"res://scenes/ui_v2/crafting_bench_ui_v2.tscn"
)
const ForgeV2StageControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const ForgeV2KeybindingStateScript = preload(
	"res://runtime/forge_v2/forge_v2_keybinding_state.gd"
)
const PlayerToolProfileLibraryStateScript = preload(
	"res://core/models/player_tool_profile_library_state.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_detailing_brush_ui_input_2026-08-10.txt"
)
const TARGET_KIND := &"placement_plane"
const TARGET_ID := &"forge_v2_placement_plane"
const POSITION_SCALE := 0.001

var result_lines: PackedStringArray = []


class SurfaceWorkspaceStub:
	extends Node3D

	var nearest_point_index := -1
	var reject_locked_hits := false
	var miss_range_min_x := INF
	var miss_range_max_x := -INF
	var strict_requests: Array[Dictionary] = []

	func resolve_strict_surface_target(
		screen_position: Vector2,
		required_target_kind: StringName = StringName(),
		required_target_id: StringName = StringName()
	) -> Dictionary:
		strict_requests.append({
			"screen_position": screen_position,
			"required_target_kind": required_target_kind,
			"required_target_id": required_target_id,
		})
		if reject_locked_hits and required_target_id != StringName():
			return {"valid": false, "reject_reason": &"locked_miss"}
		if (
			screen_position.x >= miss_range_min_x
			and screen_position.x <= miss_range_max_x
		):
			return {"valid": false, "reject_reason": &"surface_gap"}
		if (
			required_target_kind != StringName()
			and required_target_kind != TARGET_KIND
		):
			return {"valid": false, "reject_reason": &"kind_mismatch"}
		if (
			required_target_id != StringName()
			and required_target_id != TARGET_ID
		):
			return {"valid": false, "reject_reason": &"id_mismatch"}
		return {
			"valid": true,
			"target_kind": TARGET_KIND,
			"surface_target_id": TARGET_ID,
			"local_position": Vector3(
				screen_position.x * POSITION_SCALE,
				0.0,
				screen_position.y * POSITION_SCALE
			),
			"local_normal": Vector3.UP,
			"local_contact_direction": Vector3.DOWN,
		}

	func project_workspace_local_to_screen(
		local_position: Vector3
	) -> Dictionary:
		return {
			"valid": true,
			"screen_position": Vector2(
				local_position.x / POSITION_SCALE,
				local_position.z / POSITION_SCALE
			),
		}

	func find_nearest_local_point_by_screen(
		_points: PackedVector3Array,
		_screen_position: Vector2,
		_pick_radius: float
	) -> int:
		return nearest_point_index


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var controller: Node = ForgeV2StageControllerScript.new()
	get_root().add_child(controller)
	await process_frame
	var ui: CanvasLayer = CraftingBenchUIV2Scene.instantiate() as CanvasLayer
	var isolated_profile_library: Resource = (
		PlayerToolProfileLibraryStateScript.new()
	)
	isolated_profile_library.set(
		"save_file_path",
		"C:/WORKSPACE/godot_runs/verify_detail_ui_profile_library.tres"
	)
	ui.set("tool_profile_library_state", isolated_profile_library)
	var isolated_keybindings: Resource = ForgeV2KeybindingStateScript.new()
	isolated_keybindings.set(
		"save_file_path",
		"C:/WORKSPACE/godot_runs/verify_detail_ui_keybindings.json"
	)
	ui.set("keybinding_state", isolated_keybindings)
	get_root().add_child(ui)
	await process_frame
	ui.call("open_for", null, controller, "Detailing UI Verify", null)
	await process_frame
	controller.call("set_active_tool_id", &"tool_detailing_brush")
	await process_frame

	var old_workspace: Node = ui.get("workspace_preview") as Node
	if is_instance_valid(old_workspace):
		old_workspace.queue_free()
		await process_frame
	var workspace := SurfaceWorkspaceStub.new()
	var workspace_subviewport := ui.get("workspace_subviewport") as SubViewport
	workspace_subviewport.add_child(workspace)
	ui.set("workspace_preview", workspace)

	ui.call("_begin_workspace_spline_input", Vector2(10.0, 0.0))
	await process_frame
	var first := _detail_summary(controller)
	if not _check(
		(first.get("control_points", PackedVector3Array()) as PackedVector3Array).size() == 1
		and (first.get("control_surface_normals", PackedVector3Array()) as PackedVector3Array).size() == 1
		and (first.get(
			"control_contact_directions",
			PackedVector3Array()
		) as PackedVector3Array) == PackedVector3Array([Vector3.DOWN])
		and StringName(first.get("locked_target_kind", StringName())) == TARGET_KIND
		and StringName(first.get("locked_target_id", StringName())) == TARGET_ID
		and not bool(first.get("valid", true))
		and StringName(first.get("reason", StringName())) == &"not_ready",
		(
			"first Detail dot did not persist one paired control and locked target "
			+ "as not-ready: %s" % str(first)
		)
	):
		return
	result_lines.append("first_dot_locks_target_and_stays_not_ready=true")

	ui.call("_begin_workspace_spline_input", Vector2(30.0, 0.0))
	await process_frame
	var second := _detail_summary(controller)
	if not _check(
		(second.get("control_points", PackedVector3Array()) as PackedVector3Array).size() == 2
		and bool(second.get("valid", false))
		and bool(second.get("can_generate", false))
		and (second.get("resolved_path_points", PackedVector3Array()) as PackedVector3Array).size() >= 3,
		"second Detail dot did not produce a generation-ready strict surface solution"
	):
		return
	if not _check(
		(second.get(
			"resolved_contact_directions",
			PackedVector3Array()
		) as PackedVector3Array).size()
		== (second.get(
			"resolved_path_points",
			PackedVector3Array()
		) as PackedVector3Array).size(),
		"Detail solution did not retain one explicit B-C per resolved point"
	):
		return
	if not _check(
		_has_locked_request(workspace.strict_requests),
		"later Detail solving did not query the exact locked target"
	):
		return
	result_lines.append("later_add_uses_exact_locked_target=true")

	var before_miss := (
		second.get("control_points", PackedVector3Array()) as PackedVector3Array
	).duplicate()
	workspace.reject_locked_hits = true
	ui.call("_begin_workspace_spline_input", Vector2(50.0, 0.0))
	await process_frame
	workspace.reject_locked_hits = false
	var after_miss := _detail_summary(controller)
	if not _check(
		(after_miss.get("control_points", PackedVector3Array()) as PackedVector3Array)
		== before_miss,
		"locked-target miss changed the existing Detail controls"
	):
		return
	result_lines.append("locked_add_miss_preserves_state=true")

	workspace.nearest_point_index = 0
	ui.call("_begin_workspace_spline_input", Vector2(12.0, 0.0))
	await process_frame
	if not _check(
		bool(ui.get("workspace_spline_point_drag_active")),
		"Detail control did not enter strict surface drag mode"
	):
		return
	var drag_started := _detail_summary(controller)
	var drag_started_points := (
		drag_started.get("control_points", PackedVector3Array())
		as PackedVector3Array
	).duplicate()
	workspace.reject_locked_hits = true
	ui.call("_update_workspace_spline_point_drag", Vector2(18.0, 0.0))
	await process_frame
	workspace.reject_locked_hits = false
	var drag_after_miss := _detail_summary(controller)
	if not _check(
		(drag_after_miss.get("control_points", PackedVector3Array()) as PackedVector3Array)
		== drag_started_points,
		"locked-target drag miss changed the paired Detail controls"
	):
		return
	ui.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	await process_frame
	if not _check(
		bool(ui.call("is_open"))
		and not bool(ui.get("workspace_spline_point_drag_active"))
		and (
			_detail_summary(controller).get(
				"control_points",
				PackedVector3Array()
			) as PackedVector3Array
		) == drag_started_points,
		"focus loss left Detail drag ownership active or mutated its controls"
	):
		return
	result_lines.append("focus_loss_releases_detail_drag_without_closing_ui=true")
	ui.call("_begin_workspace_spline_input", Vector2(13.0, 0.0))
	await process_frame
	var release_event := InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	release_event.position = Vector2(14.0, 0.0)
	ui.call("_handle_workspace_mouse_button", release_event)
	await process_frame
	var drag_released := _detail_summary(controller)
	var released_points := drag_released.get(
		"control_points",
		PackedVector3Array()
	) as PackedVector3Array
	if not _check(
		not bool(ui.get("workspace_spline_point_drag_active"))
		and is_equal_approx(released_points[0].x, 0.014),
		"Detail drag release did not retain the exact final valid surface hit"
	):
		return
	result_lines.append("locked_drag_miss_is_atomic_and_release_is_exact=true")

	workspace.nearest_point_index = -1
	workspace.miss_range_min_x = 34.0
	workspace.miss_range_max_x = 46.0
	ui.call("_begin_workspace_spline_input", Vector2(50.0, 0.0))
	await process_frame
	var invalid_span := _detail_summary(controller)
	var invalid_controls := invalid_span.get(
		"control_points",
		PackedVector3Array()
	) as PackedVector3Array
	if not _check(
		invalid_controls.size() == 3
		and not bool(invalid_span.get("valid", true))
		and not bool(invalid_span.get("can_generate", true)),
		"invalid resolved span was not retained as a disabled diagnostic state"
	):
		return
	result_lines.append("invalid_span_persists_but_generation_is_disabled=true")

	ui.call("_rebuild_v2_action_menus")
	var shape_button := ui.get("shape_menu_button") as MenuButton
	var shape_popup := shape_button.get_popup()
	if not _check(
		is_instance_valid(shape_popup.get_node_or_null("Tool2DProfilesSubmenu"))
		and _popup_has_item(shape_popup, "Generate Detailing Brush")
		and not _popup_has_item(shape_popup, "Generate CSG Noodle"),
		"Detailing Brush Shape menu lost 2D profiles or used free-Spline generation labels"
	):
		return
	result_lines.append("shape_menu_profiles_and_detailing_labels=true")

	_finish(true)


func _detail_summary(controller: Node) -> Dictionary:
	var summary: Dictionary = controller.call("get_status_summary") as Dictionary
	return summary.get("detailing_brush", {}) as Dictionary


func _has_locked_request(requests: Array[Dictionary]) -> bool:
	for request: Dictionary in requests:
		if (
			StringName(request.get("required_target_kind", StringName()))
			== TARGET_KIND
			and StringName(request.get("required_target_id", StringName()))
			== TARGET_ID
		):
			return true
	return false


func _popup_has_item(popup: PopupMenu, expected_text: String) -> bool:
	for item_index in range(popup.item_count):
		if popup.get_item_text(item_index) == expected_text:
			return true
	return false


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	result_lines.append("FAIL: %s" % message)
	_finish(false)
	return false


func _finish(success: bool) -> void:
	result_lines.append("result=%s" % ("PASS" if success else "FAIL"))
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(result_lines) + "\n")
	quit(0 if success else 1)
