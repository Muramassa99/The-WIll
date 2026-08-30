extends SceneTree

const CraftingBenchUIV2Scene = preload(
	"res://scenes/ui_v2/crafting_bench_ui_v2.tscn"
)
const ForgeV2StageControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const ForgeV2AuthoringStateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
)
const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2KeybindingStateScript = preload(
	"res://runtime/forge_v2/forge_v2_keybinding_state.gd"
)
const PlayerToolProfileLibraryStateScript = preload(
	"res://core/models/player_tool_profile_library_state.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_handle_path_mode_menu.txt"
)
const ACTION_HANDLE_PATH_MODE := &"handle_path_mode"
const MODE_THREE_POINT_SPLINE := &"handle_path_3_point_spline"
const MODE_THREE_POINT_LINEAR := &"handle_path_3_point_linear"
const MODE_TWO_POINT_LINEAR := &"handle_path_2_point_linear"
const SHAPE_KIND_PROFILE_PATH := &"shape_kind_profile_path"
const SHAPE_KIND_SPLINE_PROFILE_PATH := &"shape_kind_spline_profile_path"
const EXPECTED_MODES: Array[Dictionary] = [
	{
		"label": "3 point spline",
		"value": MODE_THREE_POINT_SPLINE,
	},
	{
		"label": "3 point linear",
		"value": MODE_THREE_POINT_LINEAR,
	},
	{
		"label": "2 point linear",
		"value": MODE_TWO_POINT_LINEAR,
	},
]

var result_lines: PackedStringArray = []


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
		"C:/WORKSPACE/godot_runs/verify_handle_mode_profiles.tres"
	)
	ui.set("tool_profile_library_state", isolated_profile_library)
	var isolated_keybindings: Resource = ForgeV2KeybindingStateScript.new()
	isolated_keybindings.set(
		"save_file_path",
		"C:/WORKSPACE/godot_runs/verify_handle_mode_keybindings.json"
	)
	ui.set("keybinding_state", isolated_keybindings)
	get_root().add_child(ui)
	await process_frame
	ui.call("open_for", null, controller, "Handle Mode Menu Verify", null)
	await process_frame
	ui.call("_rebuild_v2_action_menus")

	var hierarchy := _resolve_handle_mode_menu(ui)
	if not _check(
		bool(hierarchy.get("ok", false)),
		String(hierarchy.get("failure", "Handle mode menu was not built"))
	):
		return
	var handle_mode_submenu := hierarchy.get("submenu") as PopupMenu
	if not _check(
		not handle_mode_submenu.hide_on_checkable_item_selection,
		"Handle mode submenu hides when a checkable mode is selected"
	):
		return
	result_lines.append("hide_on_checkable_item_selection=false")

	if not _verify_exact_mode_contract(ui, handle_mode_submenu):
		return
	result_lines.append("shape_tool_handles_hierarchy=true")
	result_lines.append("exact_mode_contract=true")

	if not await _select_mode(ui, MODE_THREE_POINT_SPLINE):
		return
	var state := controller.call("get_active_authoring_state") as Resource
	if not _check(
		StringName(state.get("active_tool_id")) == &"tool_handles",
		"Selecting a Handle path mode did not activate the Handles tool"
	):
		return

	var start_point := Vector3(-0.2, 0.0, 0.0)
	var middle_point := Vector3(0.0, 0.1, 0.0)
	var end_point := Vector3(0.2, 0.0, 0.0)
	controller.call("append_spline_line_point", start_point, Vector3.FORWARD)
	controller.call("append_spline_line_point", middle_point, Vector3.UP)
	controller.call("append_spline_line_point", end_point, Vector3.BACK)
	await process_frame
	if not _check(
		_get_path_points(state).size() == 3,
		"Three-point Handle setup did not retain three authored points"
	):
		return

	if not await _select_mode(ui, MODE_TWO_POINT_LINEAR):
		return
	var two_point_path := _get_path_points(state)
	if not _check(
		StringName(state.get("active_handle_path_mode_id"))
		== MODE_TWO_POINT_LINEAR
		and int(state.call("get_active_handle_required_point_count")) == 2
		and StringName(state.call("get_active_handle_path_shape_kind"))
		== SHAPE_KIND_PROFILE_PATH
		and two_point_path.size() == 2
		and two_point_path[0].is_equal_approx(start_point)
		and two_point_path[1].is_equal_approx(end_point),
		"Three-to-two mode conversion did not preserve first/last endpoints"
	):
		return
	result_lines.append("three_to_two_preserves_endpoints=true")

	if not await _select_mode(ui, MODE_THREE_POINT_LINEAR):
		return
	var restored_linear_path := _get_path_points(state)
	var expected_midpoint := start_point.lerp(end_point, 0.5)
	if not _check(
		StringName(state.get("active_handle_path_mode_id"))
		== MODE_THREE_POINT_LINEAR
		and int(state.call("get_active_handle_required_point_count")) == 3
		and StringName(state.call("get_active_handle_path_shape_kind"))
		== SHAPE_KIND_PROFILE_PATH
		and restored_linear_path.size() == 3
		and restored_linear_path[0].is_equal_approx(start_point)
		and restored_linear_path[1].is_equal_approx(expected_midpoint)
		and restored_linear_path[2].is_equal_approx(end_point),
		"Two-to-three mode conversion did not insert the deterministic midpoint"
	):
		return
	result_lines.append("two_to_three_inserts_midpoint=true")

	if not await _select_mode(ui, MODE_THREE_POINT_SPLINE):
		return
	var restored_spline_path := _get_path_points(state)
	if not _check(
		StringName(state.get("active_handle_path_mode_id"))
		== MODE_THREE_POINT_SPLINE
		and int(state.call("get_active_handle_required_point_count")) == 3
		and StringName(state.call("get_active_handle_path_shape_kind"))
		== SHAPE_KIND_SPLINE_PROFILE_PATH
		and restored_spline_path == restored_linear_path,
		"Three-point spline selection changed point count/data unexpectedly"
	):
		return
	result_lines.append("linear_to_spline_preserves_three_points=true")
	if not _verify_generated_body_modes():
		return
	result_lines.append("all_modes_generate_and_commit=true")
	_finish(true)


func _verify_generated_body_modes() -> bool:
	var cases: Array[Dictionary] = [
		{
			"mode": MODE_THREE_POINT_SPLINE,
			"shape_kind": SHAPE_KIND_SPLINE_PROFILE_PATH,
			"points": PackedVector3Array([
				Vector3(-0.2, 0.0, 0.0),
				Vector3(0.0, 0.1, 0.0),
				Vector3(0.2, 0.0, 0.0),
			]),
		},
		{
			"mode": MODE_THREE_POINT_LINEAR,
			"shape_kind": SHAPE_KIND_PROFILE_PATH,
			"points": PackedVector3Array([
				Vector3(-0.2, 0.0, 0.0),
				Vector3(0.0, 0.1, 0.0),
				Vector3(0.2, 0.0, 0.0),
			]),
		},
		{
			"mode": MODE_TWO_POINT_LINEAR,
			"shape_kind": SHAPE_KIND_PROFILE_PATH,
			"points": PackedVector3Array([
				Vector3(-0.2, 0.0, 0.0),
				Vector3(0.2, 0.0, 0.0),
			]),
		},
	]
	for case_data: Dictionary in cases:
		var state: Resource = ForgeV2AuthoringStateScript.new()
		state.call("reset_new_draft", "Handle Path Mode Generation Verify")
		state.call("reset_active_handle_profile_builder")
		state.call(
			"set_active_handle_path_mode_id",
			StringName(case_data.get("mode", StringName()))
		)
		var points := case_data.get(
			"points",
			PackedVector3Array()
		) as PackedVector3Array
		for point: Vector3 in points:
			state.call("append_spline_line_point", point, Vector3.UP)
		if not _check(
			bool(state.call("generate_profile_extrusion_from_spline")),
			"Handle mode did not generate: %s" % String(case_data.get(
				"mode",
				StringName()
			))
		):
			return false
		var body := state.call("get_selected_material_body") as Resource
		if not _check(
			body != null
			and StringName(body.get("body_kind"))
			== ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE
			and StringName(body.get("shape_kind"))
			== StringName(case_data.get("shape_kind", StringName()))
			and (body.get("path_points") as PackedVector3Array) == points,
			"Generated Handle body did not retain its selected path contract"
		):
			return false
		if not _check(
			state.call(
				"commit_material_body_as_layer",
				StringName(body.get("body_id"))
			) != null,
			"Generated Handle body did not pass commit validation"
		):
			return false
	return true


func _resolve_handle_mode_menu(ui: CanvasLayer) -> Dictionary:
	var shape_button := ui.get("shape_menu_button") as MenuButton
	if not is_instance_valid(shape_button):
		return {"ok": false, "failure": "Shape menu button is missing"}
	var shape_popup := shape_button.get_popup()
	var tool_submenu := shape_popup.get_node_or_null(
		"ToolSubmenu"
	) as PopupMenu
	if not is_instance_valid(tool_submenu):
		return {"ok": false, "failure": "Shape -> Tool submenu is missing"}
	if not _has_submenu_binding(shape_popup, "Tool", "ToolSubmenu"):
		return {
			"ok": false,
			"failure": "Shape menu does not bind Tool to ToolSubmenu",
		}
	var handle_mode_submenu := tool_submenu.get_node_or_null(
		"HandlePathModeSubmenu"
	) as PopupMenu
	if not is_instance_valid(handle_mode_submenu):
		return {
			"ok": false,
			"failure": "Shape -> Tool -> Handles submenu is missing",
		}
	if not _has_submenu_binding(
		tool_submenu,
		"Handles",
		"HandlePathModeSubmenu"
	):
		return {
			"ok": false,
			"failure": (
				"Tool menu does not bind Handles to HandlePathModeSubmenu"
			),
		}
	return {
		"ok": true,
		"submenu": handle_mode_submenu,
	}


func _has_submenu_binding(
	popup: PopupMenu,
	label: String,
	submenu_name: String
) -> bool:
	for item_index in range(popup.get_item_count()):
		if (
			popup.get_item_text(item_index) == label
			and String(popup.get_item_submenu(item_index)) == submenu_name
		):
			return true
	return false


func _verify_exact_mode_contract(
	ui: CanvasLayer,
	handle_mode_submenu: PopupMenu
) -> bool:
	if not _check(
		handle_mode_submenu.get_item_count() == EXPECTED_MODES.size(),
		"Handle mode submenu does not contain exactly three items"
	):
		return false
	var action_lookup := ui.get("menu_action_lookup") as Dictionary
	for item_index in range(EXPECTED_MODES.size()):
		var expected: Dictionary = EXPECTED_MODES[item_index]
		var menu_id := handle_mode_submenu.get_item_id(item_index)
		var entry := action_lookup.get(menu_id, {}) as Dictionary
		if not _check(
			handle_mode_submenu.get_item_text(item_index)
			== String(expected.get("label", ""))
			and StringName(entry.get("action", StringName()))
			== ACTION_HANDLE_PATH_MODE
			and StringName(entry.get("value", StringName()))
			== StringName(expected.get("value", StringName())),
			"Handle mode label/action/value mismatch at index %d" % item_index
		):
			return false
	return true


func _select_mode(ui: CanvasLayer, mode_id: StringName) -> bool:
	var hierarchy := _resolve_handle_mode_menu(ui)
	if not _check(
		bool(hierarchy.get("ok", false)),
		String(hierarchy.get("failure", "Handle mode menu disappeared"))
	):
		return false
	var submenu := hierarchy.get("submenu") as PopupMenu
	var action_lookup := ui.get("menu_action_lookup") as Dictionary
	var selected_menu_id := -1
	for item_index in range(submenu.get_item_count()):
		var menu_id := submenu.get_item_id(item_index)
		var entry := action_lookup.get(menu_id, {}) as Dictionary
		if (
			StringName(entry.get("action", StringName()))
			== ACTION_HANDLE_PATH_MODE
			and StringName(entry.get("value", StringName())) == mode_id
		):
			selected_menu_id = menu_id
			break
	if not _check(
		selected_menu_id >= 0,
		"No Handle menu action was registered for %s" % String(mode_id)
	):
		return false
	submenu.id_pressed.emit(selected_menu_id)
	await process_frame
	await process_frame
	return _verify_checked_mode(ui, mode_id)


func _verify_checked_mode(ui: CanvasLayer, mode_id: StringName) -> bool:
	var hierarchy := _resolve_handle_mode_menu(ui)
	if not _check(
		bool(hierarchy.get("ok", false)),
		String(hierarchy.get("failure", "Handle mode menu did not rebuild"))
	):
		return false
	var submenu := hierarchy.get("submenu") as PopupMenu
	var action_lookup := ui.get("menu_action_lookup") as Dictionary
	var checked_count := 0
	var checked_value := StringName()
	for item_index in range(submenu.get_item_count()):
		if not submenu.is_item_checked(item_index):
			continue
		checked_count += 1
		var menu_id := submenu.get_item_id(item_index)
		var entry := action_lookup.get(menu_id, {}) as Dictionary
		checked_value = StringName(entry.get("value", StringName()))
	return _check(
		checked_count == 1 and checked_value == mode_id,
		"Handle menu check state did not follow selected mode %s"
		% String(mode_id)
	)


func _get_path_points(state: Resource) -> PackedVector3Array:
	return state.get("spline_line_points") as PackedVector3Array


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	_finish(false, message)
	return false


func _finish(passed: bool, message: String = "") -> void:
	var output_lines := PackedStringArray([
		"ok=true" if passed else "ok=false",
	])
	output_lines.append_array(result_lines)
	if not passed:
		output_lines.append("failure=%s" % message)
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var result_file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if result_file != null:
		result_file.store_string("\n".join(output_lines) + "\n")
	if passed:
		print("FORGE_V2_HANDLE_PATH_MODE_MENU_VERIFY: PASS")
		quit()
		return
	push_error("FORGE_V2_HANDLE_PATH_MODE_MENU_VERIFY: FAIL: %s" % message)
	quit(1)
