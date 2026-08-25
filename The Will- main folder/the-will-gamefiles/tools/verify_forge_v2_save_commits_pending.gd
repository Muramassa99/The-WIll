extends SceneTree

const CraftingBenchUiV2Scene = preload(
	"res://scenes/ui_v2/crafting_bench_ui_v2.tscn"
)
const StageControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const AuthoringStateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
)
const ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const WipLibraryScript = preload(
	"res://core/models/player_forge_wip_library_state.gd"
)
const ToolProfileLibraryScript = preload(
	"res://core/models/player_tool_profile_library_state.gd"
)
const KeybindingStateScript = preload(
	"res://runtime/forge_v2/forge_v2_keybinding_state.gd"
)

const TEMP_LIBRARY_PATH := (
	"user://tests/verify_forge_v2_save_commits_pending.tres"
)
const TEMP_PROFILE_LIBRARY_PATH := (
	"user://tests/verify_forge_v2_save_commits_pending_profiles.tres"
)
const TEMP_KEYBINDINGS_PATH := (
	"user://tests/verify_forge_v2_save_commits_pending_keys.json"
)
const SAVE_WAIT_FRAME_LIMIT := 1800
const HANDLE_POINTS: Array[Vector3] = [
	Vector3(-0.20, 0.0, 0.0),
	Vector3.ZERO,
	Vector3(0.20, 0.0, 0.0),
]


class FakePlayer extends Node:
	var wip_library: PlayerForgeWipLibraryState

	func _init(library: PlayerForgeWipLibraryState) -> void:
		wip_library = library

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return wip_library


var _controller: Node = null
var _ui: CanvasLayer = null
var _library: PlayerForgeWipLibraryState = null
var _counted_export_request_count := 0


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	_cleanup_temp_library()
	_library = WipLibraryScript.new() as PlayerForgeWipLibraryState
	_library.save_file_path = TEMP_LIBRARY_PATH
	var fake_player := FakePlayer.new(_library)
	fake_player.name = "SaveTransactionFakePlayer"
	root.add_child(fake_player)

	_controller = StageControllerScript.new() as Node
	_controller.name = "SaveTransactionStageController"
	root.add_child(_controller)
	_ui = CraftingBenchUiV2Scene.instantiate() as CanvasLayer
	_ui.name = "SaveTransactionForgeUi"
	var isolated_profile_library := ToolProfileLibraryScript.new()
	isolated_profile_library.set("save_file_path", TEMP_PROFILE_LIBRARY_PATH)
	_ui.set("tool_profile_library_state", isolated_profile_library)
	var isolated_keybindings := KeybindingStateScript.new()
	isolated_keybindings.set("save_file_path", TEMP_KEYBINDINGS_PATH)
	_ui.set("keybinding_state", isolated_keybindings)
	root.add_child(_ui)
	await process_frame
	_ui.call("open_for", fake_player, _controller, "Save Transaction Test")
	await process_frame
	await physics_frame

	if not _expect(_author_pending_handle(), "could not author pending Handle"):
		return
	var state := _controller.call("get_active_authoring_state") as Resource
	if not _expect(
		int(state.call("get_pending_material_body_count")) == 1,
		"Handle was not pending before ordinary Save"
	):
		return
	if not _expect(
		bool(_ui.call("_save_current_v2_draft")),
		"ordinary Save request was rejected"
	):
		return
	if not await _wait_for_save_transaction():
		_fail("ordinary Save transaction did not settle")
		return
	if not _expect(
		int(state.call("get_pending_material_body_count")) == 0,
		"ordinary Save left the Handle pending"
	):
		return
	if not _expect(
		int(state.call("get_committed_layer_count")) >= 1,
		"ordinary Save did not commit the pending Handle layer"
	):
		return
	if not _expect(
		_library.saved_wips.size() == 1,
		"ordinary Save did not persist exactly one WIP"
	):
		return
	var source_wip: CraftedItemWIP = _library.saved_wips[0]
	var source_wip_id := source_wip.wip_id

	if not _expect(_author_pending_noodle(), "could not author pending noodle"):
		return
	state = _controller.call("get_active_authoring_state") as Resource
	if not _expect(
		int(state.call("get_pending_material_body_count")) == 1,
		"noodle was not pending before Save As"
	):
		return
	if not _expect(
		bool(_ui.call("_save_current_v2_draft_as", "Pending Commit Copy")),
		"Save As request was rejected"
	):
		return
	if not await _wait_for_save_transaction():
		_fail("Save As transaction did not settle")
		return
	if not _expect(
		int(state.call("get_pending_material_body_count")) == 0,
		"Save As left the noodle pending"
	):
		return
	if not _expect(
		_library.saved_wips.size() == 2,
		"Save As did not persist a second WIP"
	):
		return
	var saved_copy := _library.get_saved_wip(
		_controller.call("get_active_saved_wip_id") as StringName
	)
	if not _expect(
		saved_copy != null
		and saved_copy.wip_id != source_wip_id
		and saved_copy.forge_project_name == "Pending Commit Copy",
		"Save As did not create and select the requested distinct WIP"
	):
		return
	if not _expect(
		FileAccess.file_exists(TEMP_LIBRARY_PATH),
		"committed Save/Save As library was not written to disk"
	):
		return
	if not await _verify_export_failure_and_packet_handoff():
		return

	print("FORGE_V2_SAVE_COMMITS_PENDING_VERIFY: PASS")
	_cleanup_temp_library()
	quit(0)


func _author_pending_handle() -> bool:
	var handle_profiles: Array[Dictionary] = (
		ProfileShapeLibraryScript.build_handle_profile_entries()
	)
	if handle_profiles.is_empty():
		return false
	var profile_id := StringName(handle_profiles[0].get("id", StringName()))
	_controller.call("set_active_tool_id", AuthoringStateScript.TOOL_HANDLES)
	_controller.call("set_active_profile_id", profile_id)
	for point: Vector3 in HANDLE_POINTS:
		if int(_controller.call(
			"append_spline_line_point",
			point,
			Vector3.UP
		)) < 0:
			return false
	return bool(_controller.call("generate_profile_extrusion_from_spline"))


func _author_pending_noodle() -> bool:
	_controller.call("set_active_tool_id", AuthoringStateScript.TOOL_SPLINE_LINE)
	for point: Vector3 in [
		Vector3(0.0, -0.08, 0.0),
		Vector3(0.0, 0.08, 0.0),
	]:
		if int(_controller.call(
			"append_spline_line_point",
			point,
			Vector3.FORWARD
		)) < 0:
			return false
	return bool(_controller.call("generate_spline_line_csg_noodle"))


func _wait_for_save_transaction() -> bool:
	for _frame_index in range(SAVE_WAIT_FRAME_LIMIT):
		if not bool(_ui.get("v2_save_in_progress")):
			return true
		await process_frame
		await physics_frame
	return false


func _verify_export_failure_and_packet_handoff() -> bool:
	var active_wip_id := StringName(_controller.call("get_active_saved_wip_id"))
	var isolated_source := _library.get_saved_wip_clone(active_wip_id, false)
	var isolated_controller := StageControllerScript.new() as Node
	isolated_controller.name = "IsolatedSavePacketController"
	root.add_child(isolated_controller)
	await process_frame
	if not _expect(
		isolated_source != null
		and bool(isolated_controller.call("load_saved_wip", isolated_source)),
		"could not isolate a saved WIP for export-failure checks"
	):
		isolated_controller.queue_free()
		return false
	var state := isolated_controller.call("get_active_authoring_state") as Resource
	var saved_count_before := _library.saved_wips.size()
	state.call(
		"set_runtime_contract_mesh_export_provider",
		Callable(self, "_build_terminal_export_packet")
	)
	var terminal_result := await isolated_controller.call(
		"prepare_pending_work_for_save",
		1000
	) as Dictionary
	if not _expect(
		not bool(terminal_result.get("ok", true))
		and StringName(terminal_result.get("reason", StringName()))
		== &"runtime_mesh_export_failed"
		and String(terminal_result.get("error_code", ""))
		== "VERIFY_TERMINAL_EXPORT",
		"terminal runtime export error was not rejected"
	):
		return false
	if not _expect(
		_library.saved_wips.size() == saved_count_before,
		"terminal export failure mutated the saved WIP library"
	):
		return false

	state.call(
		"set_runtime_contract_mesh_export_provider",
		Callable(self, "_build_pending_export_packet")
	)
	var timeout_result := await isolated_controller.call(
		"prepare_pending_work_for_save",
		25
	) as Dictionary
	if not _expect(
		not bool(timeout_result.get("ok", true))
		and StringName(timeout_result.get("reason", StringName()))
		== &"save_preparation_timed_out",
		"forever-pending runtime export did not stop at the finite timeout"
	):
		return false

	_counted_export_request_count = 0
	state.call(
		"set_runtime_contract_mesh_export_provider",
		Callable(self, "_build_counted_valid_export_packet")
	)
	var ready_result := await isolated_controller.call(
		"prepare_pending_work_for_save",
		1000
	) as Dictionary
	if not _expect(
		bool(ready_result.get("ok", false))
		and _counted_export_request_count == 1,
		"ready packet was not obtained exactly once"
	):
		return false
	var saved_with_ready_packet := isolated_controller.call(
		"save_current_wip",
		_library,
		ready_result.get("runtime_mesh_packet", {}) as Dictionary
	) as CraftedItemWIP
	var packet_handoff_ok := _expect(
		saved_with_ready_packet != null
		and _counted_export_request_count == 1,
		"save re-requested export instead of using the prepared packet"
	)
	isolated_controller.queue_free()
	return packet_handoff_ok


func _build_terminal_export_packet() -> Dictionary:
	return {
		"ok": false,
		"pending": false,
		"error_code": "VERIFY_TERMINAL_EXPORT",
		"reason": "intentional_verifier_failure",
	}


func _build_pending_export_packet() -> Dictionary:
	return {
		"ok": false,
		"pending": true,
		"error_code": "VERIFY_PENDING_EXPORT",
	}


func _build_counted_valid_export_packet() -> Dictionary:
	_counted_export_request_count += 1
	return {
		"ok": true,
		"vertices": PackedVector3Array([
			Vector3(0.0, 0.0, 0.0),
			Vector3(0.1, 0.0, 0.0),
			Vector3(0.0, 0.1, 0.0),
			Vector3(0.0, 0.0, 0.1),
		]),
		"indices": PackedInt32Array([
			0, 2, 1,
			0, 1, 3,
			0, 3, 2,
			1, 2, 3,
		]),
	}


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error("FORGE_V2_SAVE_COMMITS_PENDING_VERIFY: FAIL: %s" % message)
	_cleanup_temp_library()
	quit(1)


func _cleanup_temp_library() -> void:
	for resource_path: String in [
		TEMP_LIBRARY_PATH,
		TEMP_PROFILE_LIBRARY_PATH,
		TEMP_KEYBINDINGS_PATH,
	]:
		var absolute_path := ProjectSettings.globalize_path(resource_path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
