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
const ForgeServiceScript = preload("res://services/forge_service.gd")
const GripHandlePacketScript = preload("res://core/resolvers/primary_grip_handle_mesh_packet.gd")
const WipAdapterScript = preload("res://runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd")
const WrapperValidationScript = preload("res://core/resolvers/prepared_grip_target_wrapper_resolver.gd")

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


class ObservedWipLibrary extends PlayerForgeWipLibraryState:
	var save_attempt_count := 0
	var persist_attempt_count := 0
	var reject_persistence := false

	func save_wip(source_wip: CraftedItemWIP) -> CraftedItemWIP:
		save_attempt_count += 1
		return super.save_wip(source_wip)

	func persist() -> bool:
		persist_attempt_count += 1
		if reject_persistence:
			return false
		# A local test subclass has no standalone Resource script path. Persist
		# the production resource type so a fresh reload is a real library too.
		var disk_state := PlayerForgeWipLibraryState.new()
		disk_state.saved_wips = saved_wips
		disk_state.unarmed_authoring_wip = unarmed_authoring_wip
		disk_state.selected_wip_id = selected_wip_id
		disk_state.save_file_path = save_file_path
		disk_state.wip_id_generation_sequence = wip_id_generation_sequence
		return disk_state.persist()


var _controller: Node = null
var _ui: CanvasLayer = null
var _library: ObservedWipLibrary = null
var _counted_export_request_count := 0
var _counted_export_packet: Dictionary = {}
var _feedback_test_phase := "initial"
var _terminal_export_request_count := 0


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	_cleanup_temp_library()
	_library = ObservedWipLibrary.new()
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
	if not _expect(_save_label() != null and not _save_label().visible,
		"save progress was not hidden on opening Forge"):
		return

	if not _expect(_author_pending_handle(), "could not author pending Handle"):
		return
	_feedback_test_phase = "ordinary Save"
	var state := _controller.call("get_active_authoring_state") as Resource
	if not _expect(
		int(state.call("get_pending_material_body_count")) == 1,
		"Handle was not pending before ordinary Save"
	):
		return
	var save_persist_attempts_before := _library.persist_attempt_count
	if not _expect(
		bool(_ui.call("_save_current_v2_draft")),
		"ordinary Save request was rejected"
	):
		return
	if not _expect_save_start():
		return
	_ui.call("_apply_v2_action_bar_layout", true, true)
	_ui.call("_refresh_from_controller")
	if not _expect(_save_label().visible and _save_label().text == "0%",
		"compact layout or regular refresh hid/overwrote active save progress"):
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
	if not _expect(_library.persist_attempt_count == save_persist_attempts_before + 1,
		"ordinary Save performed more than its single checked persistence call"):
		return
	var source_wip: CraftedItemWIP = _library.saved_wips[0]
	var source_wip_id := source_wip.wip_id
	var first_success_fade := _ui.get("_v2_save_feedback_tween") as Tween
	if not _expect(first_success_fade != null and first_success_fade.is_valid(),
		"ordinary Save did not create success feedback fade"):
		return
	first_success_fade.pause()

	if not _expect(_author_pending_noodle(), "could not author pending noodle"):
		return
	_feedback_test_phase = "Save As replacing success fade"
	state = _controller.call("get_active_authoring_state") as Resource
	if not _expect(
		int(state.call("get_pending_material_body_count")) == 1,
		"noodle was not pending before Save As"
	):
		return
	var save_as_persist_attempts_before := _library.persist_attempt_count
	if not _expect(
		bool(_ui.call("_save_current_v2_draft_as", "Pending Commit Copy")),
		"Save As request was rejected"
	):
		return
	if not _expect_save_start():
		return
	if not _expect(not first_success_fade.is_valid(),
		"Save As did not kill the previous success fade"):
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
	if not _expect(_library.persist_attempt_count == save_as_persist_attempts_before + 1,
		"Save As performed more than its single checked persistence call"):
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
	if not _finish_feedback_fade():
		return
	if not await _verify_ui_failure_feedback():
		return
	if not await _verify_ui_close_reopen_at_write_boundary(fake_player):
		return
	if not await _verify_ui_authoring_change_at_write_boundary():
		return
	if not await _verify_export_failure_and_packet_handoff():
		return
	if not await _verify_profile_change_resave():
		return

	print("FORGE_V2_SAVE_COMMITS_PENDING_VERIFY: PASS")
	_cleanup_temp_library()
	quit(0)


func _verify_profile_change_resave() -> bool:
	_feedback_test_phase = "Change Handle profile then resave existing WIP"
	var saved_id := StringName(_controller.call("get_active_saved_wip_id"))
	var old_saved := _library.get_saved_wip_clone(saved_id, false)
	var old_handle := WipAdapterScript.resolve_valid_handle_body(old_saved.forge_v2_authoring_state)
	var old_signature := GripHandlePacketScript.build_body_signature(old_handle.body)
	var activation: Dictionary = _controller.call("activate_handle_tool")
	if not _expect(bool(activation.get("ok", false)), "could not enter Change Handle: " + str(activation)):
		return false
	_controller.call("set_active_handle_face_count", ProfileShapeLibraryScript.HANDLE_FACE_COUNT_OCTAGON)
	_controller.call("set_active_handle_rounding_enabled", false)
	# Save must auto-apply the visible edited Handle, rebuild material + target,
	# and replace this WIP rather than leave Skill Crafter with its prior snapshot.
	if not _expect(bool(_ui.call("_save_current_v2_draft")), "profile-change Save was rejected"):
		return false
	if not await _wait_for_save_transaction():
		return false
	var saved := _library.get_saved_wip_clone(saved_id, false)
	var changed_handle := WipAdapterScript.resolve_valid_handle_body(saved.forge_v2_authoring_state)
	var changed_signature := GripHandlePacketScript.build_body_signature(changed_handle.body)
	var packet := ForgeServiceScript.new()._build_forge_v2_runtime_mesh_packet(saved)
	if not _expect(changed_signature != old_signature
		and String(packet.get("primary_grip_handle_body_signature", "")) == changed_signature,
		"changed profile was not carried from authoring into saved physical geometry"):
		return false
	var wrapper := saved.stage2_item_state.get("primary_grip_target_wrapper") as Resource
	if not _expect(bool(WrapperValidationScript.validate(wrapper, packet).get("valid", false)),
		"resaved wrapper does not match the changed physical Handle"):
		return false
	var disk_library := ResourceLoader.load(TEMP_LIBRARY_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PlayerForgeWipLibraryState
	if not _expect(disk_library != null, "fresh saved library could not be loaded"):
		return false
	var disk_saved := disk_library.get_saved_wip_clone(saved_id, false)
	var disk_packet := ForgeServiceScript.new()._build_forge_v2_runtime_mesh_packet(disk_saved)
	if not _expect(String(disk_packet.get("primary_grip_handle_body_signature", "")) == changed_signature,
		"changed profile did not survive fresh disk reload"):
		return false
	print("FORGE_V2_PROFILE_RESAVE: changed authoring/material/wrapper survive disk reload")
	return _finish_feedback_fade()


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


func _save_label() -> Label:
	return _ui.get("v2_save_progress_label") as Label


func _expect_save_start() -> bool:
	var label := _save_label()
	return _expect(label != null and label.visible and label.text == "0%"
		and is_equal_approx(label.modulate.a, 1.0)
		and bool(_ui.get("v2_save_in_progress")),
		"save did not start with visible opaque 0%")


func _wait_for_save_transaction(
	expected_feedback: String = "Saved",
	require_write_boundary: bool = true
) -> bool:
	var previous_progress := -1
	var saw_write_boundary := false
	for _frame_index in range(SAVE_WAIT_FRAME_LIMIT):
		if not bool(_ui.get("v2_save_in_progress")):
			return _expect(_save_label().visible and _save_label().text == expected_feedback,
				"save feedback did not finish as '%s': %s" % [expected_feedback, _describe_save_feedback()]) and _expect(
				not require_write_boundary or saw_write_boundary,
				"save did not expose 99%% before its persistence boundary: %s" % _describe_save_feedback())
		var label := _save_label()
		var number_text := label.text.trim_suffix("%")
		if not _expect(label.visible and label.text.ends_with("%") and number_text.is_valid_int(),
			"pending save lost numeric feedback or reported success prematurely: %s" % _describe_save_feedback()):
			return false
		var progress := int(number_text)
		if not _expect(progress >= previous_progress and progress >= 0 and progress <= 99,
			"pending save progress went backwards or outside 0..99: %s" % _describe_save_feedback()):
			return false
		previous_progress = progress
		saw_write_boundary = saw_write_boundary or progress == 99
		await process_frame
	return _expect(false, "save feedback wait timed out: %s" % _describe_save_feedback())


func _describe_save_feedback() -> String:
	var status := _ui.get("action_status_label") as Label
	return "phase=%s text='%s' visible=%s busy=%s status='%s'" % [
		_feedback_test_phase, _save_label().text, _save_label().visible,
		_ui.get("v2_save_in_progress"), status.text if status != null else "<missing>",
	]


func _finish_feedback_fade() -> bool:
	var tween := _ui.get("_v2_save_feedback_tween") as Tween
	if not _expect(tween != null and tween.is_valid(), "terminal save feedback has no fade"):
		return false
	# Godot 4.7 Tween.custom_step explicitly supports advancing a paused Tween
	# beyond its entire duration. No wall-clock delay is needed for this check.
	tween.pause()
	tween.custom_step(10.0)
	return _expect(not _save_label().visible and is_equal_approx(_save_label().modulate.a, 1.0),
		"completed feedback fade did not hide and reset opacity")


func _verify_ui_failure_feedback() -> bool:
	_feedback_test_phase = "UI preparation failure"
	# Successful Save As reloads authoring and its native presenter may still
	# publish on later frames. Unbind it before installing fault providers so
	# that publication cannot replace this test's terminal packet during the
	# UI's two-frame 0% display. The real UI/controller/save path remains active.
	var preview := _ui.get("workspace_preview") as Node
	if not _expect(preview != null and bool(preview.call("clear_stage_controller")),
		"could not isolate the export provider for UI failure feedback"):
		return false
	var state := _controller.call("get_active_authoring_state") as Resource
	var attempts_before := _library.save_attempt_count
	var saved_count_before := _library.saved_wips.size()
	var selected_before := _library.selected_wip_id
	var terminal_requests_before := _terminal_export_request_count
	state.call("set_runtime_contract_mesh_export_provider", Callable(self, "_build_terminal_export_packet"))
	if not _expect(bool(_ui.call("_save_current_v2_draft")), "UI preparation-failure Save was rejected"):
		return false
	if not _expect_save_start() or not await _wait_for_save_transaction("Save failed", false):
		return false
	if not _expect(_terminal_export_request_count > terminal_requests_before
		and _library.save_attempt_count == attempts_before,
		"preparation fault provider was bypassed or failure reached the library writer") or not _finish_feedback_fade():
		return false

	_feedback_test_phase = "UI persistence failure"
	var source := _library.get_saved_wip_clone(selected_before, false)
	_counted_export_packet = ForgeServiceScript.new()._build_forge_v2_runtime_mesh_packet(source)
	state.call("set_runtime_contract_mesh_export_provider", Callable(self, "_build_counted_valid_export_packet"))
	_library.reject_persistence = true
	if not _expect(bool(_ui.call("_save_current_v2_draft")), "UI persistence-failure Save was rejected"):
		_library.reject_persistence = false
		return false
	var failed_as_expected := await _wait_for_save_transaction("Save failed")
	_library.reject_persistence = false
	if not failed_as_expected:
		return false
	return _expect(_library.save_attempt_count == attempts_before + 1
		and _library.saved_wips.size() == saved_count_before
		and _library.selected_wip_id == selected_before,
		"failed persistence did not preserve the saved library") and _finish_feedback_fade()


func _verify_ui_close_reopen_at_write_boundary(fake_player: Node) -> bool:
	_feedback_test_phase = "cancel at 99% before persistence"
	var attempts_before := _library.save_attempt_count
	if not _expect(bool(_ui.call("_save_current_v2_draft")), "cancellable Save was rejected"):
		return false
	if not await _wait_for_ui_write_boundary(attempts_before):
		return false
	var previous_generation := int(_ui.get("_v2_save_generation"))
	_ui.call("close_ui")
	if not _expect(not _save_label().visible and not bool(_ui.get("v2_save_in_progress"))
		and int(_ui.get("_v2_save_generation")) > previous_generation,
		"closing Forge did not invalidate and hide the pending save feedback"):
		return false
	_ui.call("open_for", fake_player, _controller, "Reopened Save Transaction Test")
	_feedback_test_phase = "fresh Save after close/reopen"
	if not _expect(not _save_label().visible, "reopened Forge retained old save feedback"):
		return false
	if not _expect(bool(_ui.call("_save_current_v2_draft")), "new Save after reopening was rejected"):
		return false
	if not _expect_save_start() or not await _wait_for_save_transaction():
		return false
	return _expect(_library.save_attempt_count == attempts_before + 1,
		"stale save continuation wrote after close/reopen or disrupted the replacement save") and _finish_feedback_fade()


func _wait_for_ui_write_boundary(attempts_before: int) -> bool:
	for _frame_index in range(SAVE_WAIT_FRAME_LIMIT):
		if _save_label().text == "99%":
			return _expect(_library.save_attempt_count == attempts_before,
				"persistence preceded the 99%% boundary: %s" % _describe_save_feedback())
		if not bool(_ui.get("v2_save_in_progress")):
			break
		await process_frame
	return _expect(false, "could not observe pre-write 99%%: %s" % _describe_save_feedback())


func _verify_ui_authoring_change_at_write_boundary() -> bool:
	_feedback_test_phase = "replace authoring state at 99%"
	var attempts_before := _library.save_attempt_count
	var source := _library.get_saved_wip_clone(_library.selected_wip_id, false)
	var previous_state := _controller.call("get_active_authoring_state") as Resource
	if not _expect(bool(_ui.call("_save_current_v2_draft")), "authoring-change Save was rejected"):
		return false
	if not await _wait_for_ui_write_boundary(attempts_before):
		return false
	var replacement := _controller.call("start_new_draft", "Changed during Save") as Resource
	if not _expect(replacement != null and replacement != previous_state,
		"could not replace authoring state at the pre-write boundary"):
		return false
	if not await _wait_for_save_transaction("Save failed"):
		return false
	var status := _ui.get("action_status_label") as Label
	if not _expect(_library.save_attempt_count == attempts_before
		and status != null and "authoring state changed" in status.text,
		"changed authoring was not rejected before persistence: %s" % _describe_save_feedback()):
		return false
	if not _finish_feedback_fade():
		return false
	if not _expect(source != null and bool(_controller.call("load_saved_wip", source)),
		"could not restore saved authoring after cancellation check"):
		return false
	_feedback_test_phase = "recovery Save after authoring replacement"
	if not _expect(bool(_ui.call("_save_current_v2_draft")), "recovery Save was rejected"):
		return false
	if not _expect_save_start() or not await _wait_for_save_transaction():
		return false
	return _expect(_library.save_attempt_count == attempts_before + 1,
		"recovery after authoring replacement did not write exactly once") and _finish_feedback_fade()


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
	# A ready packet for a valid authored Handle must include its actual source
	# geometry. Reuse this run's saved packet instead of the old unrelated tetra.
	_counted_export_packet = ForgeServiceScript.new()._build_forge_v2_runtime_mesh_packet(isolated_source)
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
	_terminal_export_request_count += 1
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
	return _counted_export_packet.duplicate(true)


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
