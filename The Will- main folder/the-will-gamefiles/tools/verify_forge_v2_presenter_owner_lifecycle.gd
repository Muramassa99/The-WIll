extends SceneTree

const CraftingBenchV2Scene = preload(
	"res://scenes/world/crafting_bench_v2.tscn"
)
const ForgeV2VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)
const ForgeV2KeybindingStateScript = preload(
	"res://runtime/forge_v2/forge_v2_keybinding_state.gd"
)
const PlayerToolProfileLibraryStateScript = preload(
	"res://core/models/player_tool_profile_library_state.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_presenter_owner_lifecycle.json"
)
const LIFECYCLE_CYCLE_COUNT := 3

var _failures: Array[String] = []
var _phases: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var bench := CraftingBenchV2Scene.instantiate() as Node3D
	if bench == null:
		_finish_with_setup_failure("world bench scene did not instantiate")
		return
	var ui := bench.get_node_or_null("CraftingBenchUIV2") as CanvasLayer
	if ui == null:
		_finish_with_setup_failure("world bench scene did not contain its UI")
		return
	var isolated_library := PlayerToolProfileLibraryStateScript.new() as Resource
	isolated_library.set(
		"save_file_path",
		"C:/WORKSPACE/godot_runs/presenter_owner_lifecycle_profiles.tres"
	)
	ui.set("tool_profile_library_state", isolated_library)
	var isolated_keybindings := ForgeV2KeybindingStateScript.new() as Resource
	isolated_keybindings.set(
		"save_file_path",
		"C:/WORKSPACE/godot_runs/presenter_owner_lifecycle_keybindings.json"
	)
	ui.set("keybinding_state", isolated_keybindings)
	root.add_child(bench)
	await _settle()

	var controller := bench.get_node_or_null("Stage1V2Controller") as Node
	var world_presenter := bench.get_node_or_null("PreviewRoot") as Node3D
	var workspace := ui.get("workspace_preview") as Node3D
	var ui_presenter := (
		workspace.get("volume_preview_presenter") as Node3D
		if workspace != null
		else null
	)
	if (
		controller == null
		or world_presenter == null
		or workspace == null
		or ui_presenter == null
	):
		_finish_with_setup_failure("production presenter/controller tree was incomplete")
		bench.queue_free()
		return

	var stable_presenter_ids := [
		int(world_presenter.get_instance_id()),
		int(ui_presenter.get_instance_id()),
	]
	_capture_phase(
		"initial_world_owner",
		bench,
		ui,
		controller,
		world_presenter,
		ui_presenter,
		world_presenter,
		false,
		stable_presenter_ids
	)

	for cycle_index in range(LIFECYCLE_CYCLE_COUNT):
		bench.call("interact", null)
		await _settle()
		_capture_phase(
			"cycle_%d_ui_owner" % (cycle_index + 1),
			bench,
			ui,
			controller,
			world_presenter,
			ui_presenter,
			ui_presenter,
			true,
			stable_presenter_ids
		)

		bench.call("interact", null)
		await _settle()
		_capture_phase(
			"cycle_%d_world_owner" % (cycle_index + 1),
			bench,
			ui,
			controller,
			world_presenter,
			ui_presenter,
			world_presenter,
			false,
			stable_presenter_ids
		)

	var report := {
		"schema": "forge_v2_presenter_owner_lifecycle",
		"schema_version": 1,
		"ok": _failures.is_empty(),
		"cycle_count": LIFECYCLE_CYCLE_COUNT,
		"stable_presenter_instance_ids": stable_presenter_ids,
		"phases": _phases,
		"failures": _failures,
	}
	_write_report(report)
	bench.queue_free()
	await process_frame
	if not _failures.is_empty():
		push_error("Forge V2 presenter ownership regression failed: %s" % "; ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _capture_phase(
	phase_name: String,
	bench: Node,
	ui: CanvasLayer,
	controller: Node,
	world_presenter: Node3D,
	ui_presenter: Node3D,
	expected_owner: Node3D,
	expected_ui_open: bool,
	stable_presenter_ids: Array
) -> void:
	var presenters := _collect_presenters(bench)
	var presenter_ids: Array[int] = []
	var bound_presenter_ids: Array[int] = []
	for presenter: Node in presenters:
		presenter_ids.append(int(presenter.get_instance_id()))
		if presenter.get("active_stage_controller") == controller:
			bound_presenter_ids.append(int(presenter.get_instance_id()))
	presenter_ids.sort()
	bound_presenter_ids.sort()
	var expected_ids: Array[int] = []
	for id_variant: Variant in stable_presenter_ids:
		expected_ids.append(int(id_variant))
	expected_ids.sort()

	var signal_owner_ids := {}
	var all_signals_have_one_expected_owner := true
	for signal_name: StringName in [
		&"authoring_state_changed",
		&"material_body_preview_changed",
		&"placement_cursor_changed",
	]:
		var owner_ids := _presenter_signal_owner_ids(controller, signal_name)
		signal_owner_ids[String(signal_name)] = owner_ids
		all_signals_have_one_expected_owner = (
			all_signals_have_one_expected_owner
			and owner_ids.size() == 1
			and int(owner_ids[0]) == int(expected_owner.get_instance_id())
		)

	var state := controller.call("get_active_authoring_state") as Resource
	var provider: Callable = (
		state.get("_bounded_history_checkpoint_export_provider")
		if state != null
		else Callable()
	)
	var provider_owner := provider.get_object() if provider.is_valid() else null
	var provider_owner_id := (
		int(provider_owner.get_instance_id()) if provider_owner != null else 0
	)
	var runtime_provider: Callable = (
		state.get("_runtime_contract_mesh_export_provider")
		if state != null
		else Callable()
	)
	var runtime_provider_owner := (
		runtime_provider.get_object() if runtime_provider.is_valid() else null
	)
	var runtime_provider_owner_id := (
		int(runtime_provider_owner.get_instance_id())
		if runtime_provider_owner != null
		else 0
	)
	var world_diagnostics := _native_diagnostics(world_presenter)
	var ui_diagnostics := _native_diagnostics(ui_presenter)
	var inactive_presenter := (
		ui_presenter if expected_owner == world_presenter else world_presenter
	)
	var active_diagnostics := (
		world_diagnostics
		if expected_owner == world_presenter
		else ui_diagnostics
	)
	var inactive_diagnostics := (
		ui_diagnostics
		if inactive_presenter == ui_presenter
		else world_diagnostics
	)
	var actual_ui_open := bool(ui.call("is_open"))
	var ok: bool = (
		presenter_ids == expected_ids
		and bound_presenter_ids.size() == 1
		and int(bound_presenter_ids[0])
		== int(expected_owner.get_instance_id())
		and all_signals_have_one_expected_owner
		and provider.is_valid()
		and provider_owner == expected_owner
		and runtime_provider.is_valid()
		and runtime_provider_owner == expected_owner
		and actual_ui_open == expected_ui_open
		and String(active_diagnostics.get("lifecycle", "unobserved"))
		!= "unobserved"
		and String(inactive_diagnostics.get("lifecycle", ""))
		== "unobserved"
	)
	var phase := {
		"phase": phase_name,
		"ok": ok,
		"ui_open": actual_ui_open,
		"expected_ui_open": expected_ui_open,
		"presenter_instance_ids": presenter_ids,
		"bound_presenter_instance_ids": bound_presenter_ids,
		"expected_owner_instance_id": int(expected_owner.get_instance_id()),
		"checkpoint_provider_valid": provider.is_valid(),
		"checkpoint_provider_owner_instance_id": provider_owner_id,
		"runtime_mesh_provider_valid": runtime_provider.is_valid(),
		"runtime_mesh_provider_owner_instance_id": runtime_provider_owner_id,
		"signal_presenter_owner_instance_ids": signal_owner_ids,
		"world_native_lifecycle": String(world_diagnostics.get(
			"lifecycle",
			"unavailable"
		)),
		"ui_native_lifecycle": String(ui_diagnostics.get(
			"lifecycle",
			"unavailable"
		)),
	}
	_phases.append(phase)
	if not ok:
		_failures.append(phase_name)


func _collect_presenters(node: Node) -> Array[Node]:
	var presenters: Array[Node] = []
	if node == null:
		return presenters
	if node.get_script() == ForgeV2VolumePreviewPresenterScript:
		presenters.append(node)
	for child: Node in node.get_children():
		presenters.append_array(_collect_presenters(child))
	return presenters


func _presenter_signal_owner_ids(
	controller: Node,
	signal_name: StringName
) -> Array[int]:
	var owner_ids: Array[int] = []
	if controller == null or not controller.has_signal(signal_name):
		return owner_ids
	for connection_variant: Variant in controller.get_signal_connection_list(
		signal_name
	):
		if not connection_variant is Dictionary:
			continue
		var connection := connection_variant as Dictionary
		var callback: Callable = connection.get("callable", Callable())
		if not callback.is_valid():
			continue
		var callback_owner := callback.get_object()
		if (
			callback_owner != null
			and callback_owner.get_script()
			== ForgeV2VolumePreviewPresenterScript
		):
			owner_ids.append(int(callback_owner.get_instance_id()))
	owner_ids.sort()
	return owner_ids


func _native_diagnostics(presenter: Node) -> Dictionary:
	if (
		presenter == null
		or not presenter.has_method("get_native_static_sync_diagnostics")
	):
		return {}
	return presenter.call("get_native_static_sync_diagnostics") as Dictionary


func _settle() -> void:
	await process_frame
	await process_frame


func _finish_with_setup_failure(message: String) -> void:
	_failures.append(message)
	_write_report({
		"schema": "forge_v2_presenter_owner_lifecycle",
		"schema_version": 1,
		"ok": false,
		"cycle_count": 0,
		"phases": _phases,
		"failures": _failures,
	})
	push_error(message)
	quit(1)


func _write_report(report: Dictionary) -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % RESULT_PATH)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
