extends SceneTree

const CraftingBenchV2Scene = preload(
	"res://scenes/world/crafting_bench_v2.tscn"
)
const ForgeV2KeybindingStateScript = preload(
	"res://runtime/forge_v2/forge_v2_keybinding_state.gd"
)
const PlayerToolProfileLibraryStateScript = preload(
	"res://core/models/player_tool_profile_library_state.gd"
)
const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2VolumeStrokeScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_stroke.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_live_handle_noodle_deposition.json"
)
const STROKE_COUNT := 12
const BOUNDED_TAIL_CAPACITY := 5
const NATIVE_SETTLE_CYCLE_LIMIT := 20

var _failures: Array[String] = []
var _checks: Dictionary = {}
var _stroke_rows: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var bench := CraftingBenchV2Scene.instantiate() as Node3D
	if bench == null:
		_finish_setup_failure("production bench scene did not instantiate")
		return
	var ui := bench.get_node_or_null("CraftingBenchUIV2") as CanvasLayer
	if ui == null:
		_finish_setup_failure("production bench UI was missing")
		bench.queue_free()
		return
	_configure_isolated_ui_state(ui)
	root.add_child(bench)
	await _settle_frames(2)
	bench.call("interact", null)
	await _settle_frames(3)

	var controller := bench.get_node_or_null("Stage1V2Controller") as Node
	var world_presenter := bench.get_node_or_null("PreviewRoot") as Node3D
	var workspace := ui.get("workspace_preview") as Node3D
	var presenter := (
		workspace.get("volume_preview_presenter") as Node3D
		if workspace != null
		else null
	)
	var state := (
		controller.call("get_active_authoring_state") as Resource
		if controller != null
		else null
	)
	if (
		controller == null
		or world_presenter == null
		or workspace == null
		or presenter == null
		or state == null
	):
		_finish_setup_failure("production live bench fixture was incomplete")
		bench.queue_free()
		return

	_record_presenter_ownership_check(
		ui,
		controller,
		world_presenter,
		presenter
	)
	var handle_id := await _generate_handle_through_ui(
		ui,
		controller,
		state,
		presenter
	)
	var noodle_id := await _generate_noodle_through_ui(
		ui,
		controller,
		state,
		presenter,
		handle_id
	)
	await _run_default_deposition_sequence(
		controller,
		state,
		presenter,
		handle_id,
		noodle_id
	)
	_record_final_bounded_history_check(
		state,
		presenter,
		handle_id,
		noodle_id
	)

	var report := {
		"schema": "forge_v2_live_handle_noodle_deposition",
		"schema_version": 1,
		"ok": _failures.is_empty(),
		"contract": {
			"production_bench_scene": true,
			"ui_open": true,
			"ui_generation_handlers": [
				"_generate_active_profile_extrusion",
				"_generate_active_spline_csg_noodle",
			],
			"default_capsule_stroke_count": STROKE_COUNT,
			"bounded_tail_capacity": BOUNDED_TAIL_CAPACITY,
		},
		"checks": _checks,
		"stroke_rows": _stroke_rows,
		"failures": _failures,
	}
	_write_report(report)
	bench.queue_free()
	await process_frame
	if not _failures.is_empty():
		push_error(
			"Forge V2 live handle/noodle/deposition regression failed: %s"
			% "; ".join(_failures)
		)
	quit(0 if _failures.is_empty() else 1)


func _configure_isolated_ui_state(ui: CanvasLayer) -> void:
	var isolated_library := PlayerToolProfileLibraryStateScript.new() as Resource
	isolated_library.set(
		"save_file_path",
		"C:/WORKSPACE/godot_runs/live_handle_noodle_profiles.tres"
	)
	ui.set("tool_profile_library_state", isolated_library)
	var isolated_keybindings := ForgeV2KeybindingStateScript.new() as Resource
	isolated_keybindings.set(
		"save_file_path",
		"C:/WORKSPACE/godot_runs/live_handle_noodle_keybindings.json"
	)
	ui.set("keybinding_state", isolated_keybindings)


func _record_presenter_ownership_check(
	ui: CanvasLayer,
	controller: Node,
	world_presenter: Node3D,
	ui_presenter: Node3D
) -> void:
	var state := controller.call("get_active_authoring_state") as Resource
	var provider: Callable = (
		state.get("_bounded_history_checkpoint_export_provider")
		if state != null
		else Callable()
	)
	var provider_owner := provider.get_object() if provider.is_valid() else null
	var ok: bool = (
		bool(ui.call("is_open"))
		and ui_presenter.get("active_stage_controller") == controller
		and world_presenter.get("active_stage_controller") == null
		and provider.is_valid()
		and provider_owner == ui_presenter
	)
	_record_check("live_ui_presenter_owns_controller", ok, {
		"ui_open": bool(ui.call("is_open")),
		"ui_presenter_bound": (
			ui_presenter.get("active_stage_controller") == controller
		),
		"world_presenter_unbound": (
			world_presenter.get("active_stage_controller") == null
		),
		"checkpoint_provider_valid": provider.is_valid(),
		"checkpoint_provider_owned_by_ui_presenter": (
			provider_owner == ui_presenter
		),
	})


func _generate_handle_through_ui(
	ui: CanvasLayer,
	controller: Node,
	state: Resource,
	presenter: Node3D
) -> StringName:
	controller.call("reset_active_handle_profile_builder")
	for point: Vector3 in [
		Vector3(-0.34, -0.32, 0.0),
		Vector3(-0.12, -0.30, 0.015),
		Vector3(0.10, -0.32, 0.0),
	]:
		controller.call("append_spline_line_point", point, Vector3.FORWARD)
	var finished := bool(controller.call("finish_spline_line"))
	var count_before := int(state.call("get_user_material_body_count"))
	ui.call("_generate_active_profile_extrusion")
	var body := state.call("get_selected_material_body") as Resource
	var handle_id := (
		StringName(body.get("body_id")) if body != null else StringName()
	)
	var immediate := _pending_body_visual_evidence(presenter, handle_id)
	await _settle_frames(3)
	var stable := _pending_body_visual_evidence(presenter, handle_id)
	var ok: bool = (
		finished
		and body != null
		and int(state.call("get_user_material_body_count")) == count_before + 1
		and StringName(body.get("body_kind"))
		== ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE
		and StringName(body.get("committed_layer_id")) == StringName()
		and bool(immediate.get("visible", false))
		and bool(stable.get("visible", false))
	)
	_record_check("generate_handle_live_ui_visible", ok, {
		"path_finished": finished,
		"body_id": String(handle_id),
		"body_created": body != null,
		"body_kind": String(body.get("body_kind")) if body != null else "",
		"body_pending": (
			StringName(body.get("committed_layer_id")) == StringName()
			if body != null
			else false
		),
		"immediate_visual": immediate,
		"stable_visual": stable,
	})
	return handle_id


func _generate_noodle_through_ui(
	ui: CanvasLayer,
	controller: Node,
	state: Resource,
	presenter: Node3D,
	handle_id: StringName
) -> StringName:
	controller.call("set_active_tool_id", &"tool_spline_line")
	for point: Vector3 in [
		Vector3(-0.30, -0.19, 0.0),
		Vector3(-0.08, -0.16, 0.02),
		Vector3(0.16, -0.18, 0.0),
	]:
		controller.call("append_spline_line_point", point, Vector3.FORWARD)
	var finished := bool(controller.call("finish_spline_line"))
	var count_before := int(state.call("get_user_material_body_count"))
	ui.call("_generate_active_spline_csg_noodle")
	var body := state.call("get_selected_material_body") as Resource
	var noodle_id := (
		StringName(body.get("body_id")) if body != null else StringName()
	)
	var immediate := _pending_body_visual_evidence(presenter, noodle_id)
	await _settle_frames(3)
	var stable := _pending_body_visual_evidence(presenter, noodle_id)
	var handle_still_visible := _pending_body_visual_evidence(
		presenter,
		handle_id
	)
	var ok: bool = (
		finished
		and body != null
		and int(state.call("get_user_material_body_count")) == count_before + 1
		and StringName(body.get("shape_kind"))
		== ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_CAPSULE_PATH
		and StringName(body.get("committed_layer_id")) == StringName()
		and bool(immediate.get("visible", false))
		and bool(stable.get("visible", false))
		and bool(handle_still_visible.get("visible", false))
	)
	_record_check("generate_noodle_live_ui_visible", ok, {
		"path_finished": finished,
		"body_id": String(noodle_id),
		"body_created": body != null,
		"shape_kind": String(body.get("shape_kind")) if body != null else "",
		"body_pending": (
			StringName(body.get("committed_layer_id")) == StringName()
			if body != null
			else false
		),
		"immediate_visual": immediate,
		"stable_visual": stable,
		"handle_visual_after_noodle_generation": handle_still_visible,
	})
	return noodle_id


func _run_default_deposition_sequence(
	controller: Node,
	state: Resource,
	presenter: Node3D,
	handle_id: StringName,
	noodle_id: StringName
) -> void:
	controller.call("set_active_tool_id", &"tool_volume_stroke")
	controller.call("set_active_primitive_id", &"primitive_blob")
	controller.call(
		"set_active_operation_mode",
		ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL
	)
	controller.call(
		"set_placement_policy",
		ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
	)
	await _settle_frames(2)
	for stroke_index in range(STROKE_COUNT):
		var start := _stroke_start(stroke_index)
		var endpoint := start + Vector3(0.14, 0.0, 0.0)
		var body_id := StringName(controller.call(
			"begin_material_body_path",
			start,
			Vector3.FORWARD,
			Vector3.ZERO
		))
		var extended := bool(controller.call(
			"extend_material_body_path",
			endpoint,
			true,
			Vector3.FORWARD,
			Vector3.ZERO
		))
		var ready_before_finish := (
			bool(state.call("is_material_body_commit_ready", body_id))
			if body_id != StringName()
			else false
		)
		var finished := bool(controller.call("finish_material_body_path"))
		var finish_result := controller.call(
			"get_last_material_body_finish_result"
		) as Dictionary
		var immediate_visual := _pending_body_visual_evidence(
			presenter,
			body_id
		)
		var immediate_native := _native_snapshot(presenter)
		var settle_cycles := await _wait_for_native_idle(presenter)
		var final_native := _native_publication_evidence(presenter)
		var bounded := state.call(
			"get_bounded_presentation_descriptor"
		) as Dictionary
		var committed_body := _find_body(state, body_id)
		var committed: bool = (
			committed_body != null
			and StringName(committed_body.get("committed_layer_id"))
			!= StringName()
		)
		var expected_checkpoint_count := maxi(
			(stroke_index + 1) - BOUNDED_TAIL_CAPACITY,
			0
		)
		var row_ok: bool = (
			body_id != StringName()
			and extended
			and ready_before_finish
			and finished
			and StringName(finish_result.get("status", StringName()))
			== &"committed"
			and committed
			and bool(immediate_visual.get("visible", false))
			and bool(final_native.get("visible", false))
			and bool(bounded.get("bounded_history_enabled", false))
			and StringName(bounded.get("suspended_reason", StringName()))
			== &"none"
			and int(bounded.get("checkpoint_operation_count", -1))
			== expected_checkpoint_count
			and int(state.call("get_active_tail_layer_count"))
			== mini(stroke_index + 1, BOUNDED_TAIL_CAPACITY)
		)
		var row := {
			"stroke_index": stroke_index + 1,
			"ok": row_ok,
			"body_id": String(body_id),
			"extended": extended,
			"ready_before_finish": ready_before_finish,
			"finish_returned": finished,
			"finish_status": String(finish_result.get(
				"status",
				StringName()
			)),
			"committed_body_retained_in_tail": committed,
			"immediate_visual": immediate_visual,
			"immediate_native": immediate_native,
			"native_settle_cycles": settle_cycles,
			"final_native": final_native,
			"bounded_history_enabled": bool(bounded.get(
				"bounded_history_enabled",
				false
			)),
			"bounded_suspended_reason": String(bounded.get(
				"suspended_reason",
				StringName()
			)),
			"checkpoint_operation_count": int(bounded.get(
				"checkpoint_operation_count",
				-1
			)),
			"expected_checkpoint_operation_count": expected_checkpoint_count,
			"active_tail_layer_count": int(state.call(
				"get_active_tail_layer_count"
			)),
			"pending_body_count": int(state.call(
				"get_pending_material_body_count"
			)),
		}
		_stroke_rows.append(row)
		if not row_ok:
			_failures.append("default_deposition_stroke_%02d" % (stroke_index + 1))

	var handle_visual := _pending_body_visual_evidence(presenter, handle_id)
	var noodle_visual := _pending_body_visual_evidence(presenter, noodle_id)
	_record_check(
		"generated_bodies_survive_repeated_deposition_sync",
		bool(handle_visual.get("visible", false))
		and bool(noodle_visual.get("visible", false)),
		{
			"handle_visual": handle_visual,
			"noodle_visual": noodle_visual,
		}
	)


func _record_final_bounded_history_check(
	state: Resource,
	presenter: Node3D,
	handle_id: StringName,
	noodle_id: StringName
) -> void:
	var bounded := state.call("get_bounded_presentation_descriptor") as Dictionary
	var native := presenter.call(
		"get_native_static_sync_diagnostics"
	) as Dictionary
	var publication := _native_publication_evidence(presenter)
	var handle_body := _find_body(state, handle_id)
	var noodle_body := _find_body(state, noodle_id)
	var pending_count := int(state.call("get_pending_material_body_count"))
	var expected_checkpoint_count := STROKE_COUNT - BOUNDED_TAIL_CAPACITY
	var ok: bool = (
		bool(bounded.get("bounded_history_enabled", false))
		and StringName(bounded.get("suspended_reason", StringName())) == &"none"
		and int(bounded.get("lifetime_operation_count", -1)) == STROKE_COUNT
		and int(bounded.get("checkpoint_operation_count", -1))
		== expected_checkpoint_count
		and int(state.call("get_active_tail_layer_count"))
		== BOUNDED_TAIL_CAPACITY
		# One accumulated rest body + five tail strokes + the handle lane.
		and int(bounded.get("logical_body_count", -1))
		== BOUNDED_TAIL_CAPACITY + 2
		and pending_count == 2
		and handle_body != null
		and noodle_body != null
		and bool(native.get("history_window_enabled", false))
		and int(native.get("fallback_count", -1)) == 0
		and int(native.get("capsule_operand_failure_count", -1)) == 0
		and int(native.get("capsule_operand_pending_count", -1)) == 0
		and int(native.get("capsule_operand_bake_count", 0)) >= STROKE_COUNT
		and bool(native.get("authoritative", false))
		and not bool(native.get("publication_pending", true))
		and bool(publication.get("visible", false))
	)
	_record_check("final_bounded_1_plus_5_and_visible", ok, {
		"bounded_history_enabled": bool(bounded.get(
			"bounded_history_enabled",
			false
		)),
		"bounded_suspended_reason": String(bounded.get(
			"suspended_reason",
			StringName()
		)),
		"lifetime_operation_count": int(bounded.get(
			"lifetime_operation_count",
			-1
		)),
		"checkpoint_operation_count": int(bounded.get(
			"checkpoint_operation_count",
			-1
		)),
		"active_tail_layer_count": int(state.call(
			"get_active_tail_layer_count"
		)),
		"logical_body_count": int(bounded.get("logical_body_count", -1)),
		"pending_body_count": pending_count,
		"handle_survived": handle_body != null,
		"noodle_survived": noodle_body != null,
		"native": native,
		"publication": publication,
	})


func _stroke_start(stroke_index: int) -> Vector3:
	var column := stroke_index % 6
	var row := stroke_index / 6
	return Vector3(
		-0.45 + float(column) * 0.12,
		0.08 + float(row) * 0.04,
		0.0
	)


func _wait_for_native_idle(presenter: Node3D) -> int:
	for cycle_index in range(NATIVE_SETTLE_CYCLE_LIMIT):
		await process_frame
		await physics_frame
		var native := presenter.call(
			"get_native_static_sync_diagnostics"
		) as Dictionary
		if (
			int(native.get("capsule_operand_pending_count", -1)) == 0
			and not bool(native.get("publication_pending", true))
			and bool(native.get("authoritative", false))
		):
			await process_frame
			return cycle_index + 1
	return NATIVE_SETTLE_CYCLE_LIMIT


func _pending_body_visual_evidence(
	presenter: Node3D,
	body_id: StringName
) -> Dictionary:
	var evidence := {
		"found": false,
		"root_visible": false,
		"node_visible": false,
		"visible": false,
		"mesh_surface_count": 0,
		"non_authoritative": false,
	}
	if presenter == null or body_id == StringName():
		return evidence
	var preview_root := presenter.get("csg_active_body_root") as Node3D
	if preview_root == null or not is_instance_valid(preview_root):
		return evidence
	evidence["root_visible"] = preview_root.visible
	for child: Node in preview_root.get_children():
		if StringName(child.get_meta(
			"forge_v2_pending_body_id",
			StringName()
		)) != body_id:
			continue
		evidence["found"] = true
		evidence["node_visible"] = bool(child.get("visible"))
		evidence["non_authoritative"] = bool(child.get_meta(
			"forge_v2_non_authoritative_pending_preview",
			false
		))
		if child is MeshInstance3D:
			var mesh := (child as MeshInstance3D).mesh
			evidence["mesh_surface_count"] = (
				mesh.get_surface_count() if mesh != null else 0
			)
		evidence["visible"] = (
			bool(evidence["root_visible"])
			and bool(evidence["node_visible"])
			and int(evidence["mesh_surface_count"]) > 0
			and bool(evidence["non_authoritative"])
		)
		break
	return evidence


func _native_publication_evidence(presenter: Node3D) -> Dictionary:
	var native := presenter.call(
		"get_native_static_sync_diagnostics"
	) as Dictionary
	var root_node := presenter.get("native_static_body_root") as Node3D
	var published_node := presenter.get("native_static_published_node") as Node3D
	var mesh_instance := (
		published_node.get_node_or_null("NativeStaticMaterialBodyMesh")
		as MeshInstance3D
		if published_node != null and is_instance_valid(published_node)
		else null
	)
	var mesh_surface_count := (
		mesh_instance.mesh.get_surface_count()
		if mesh_instance != null and mesh_instance.mesh != null
		else 0
	)
	var root_visible := (
		root_node.visible
		if root_node != null and is_instance_valid(root_node)
		else false
	)
	var publication_visible := (
		published_node.visible
		if published_node != null and is_instance_valid(published_node)
		else false
	)
	return {
		"visible": (
			root_visible
			and publication_visible
			and mesh_instance != null
			and mesh_instance.visible
			and mesh_surface_count > 0
		),
		"root_visible": root_visible,
		"published_node_exists": (
			published_node != null and is_instance_valid(published_node)
		),
		"published_node_visible": publication_visible,
		"mesh_instance_exists": mesh_instance != null,
		"mesh_surface_count": mesh_surface_count,
		"lifecycle": String(native.get("lifecycle", "unavailable")),
		"authoritative": bool(native.get("authoritative", false)),
		"publication_pending": bool(native.get("publication_pending", false)),
		"expected_revision": int(native.get("expected_revision", -1)),
		"published_revision": int(native.get("published_revision", -1)),
		"last_failure_reason": String(native.get("last_failure_reason", "")),
	}


func _native_snapshot(presenter: Node3D) -> Dictionary:
	var native := presenter.call(
		"get_native_static_sync_diagnostics"
	) as Dictionary
	return {
		"lifecycle": String(native.get("lifecycle", "unavailable")),
		"authoritative": bool(native.get("authoritative", false)),
		"publication_pending": bool(native.get("publication_pending", false)),
		"capsule_operand_pending_count": int(native.get(
			"capsule_operand_pending_count",
			-1
		)),
		"capsule_operand_request_count": int(native.get(
			"capsule_operand_request_count",
			0
		)),
		"last_failure_reason": String(native.get("last_failure_reason", "")),
	}


func _find_body(state: Resource, body_id: StringName) -> Resource:
	if state == null or body_id == StringName():
		return null
	for body_variant: Variant in state.get("material_bodies") as Array:
		if not body_variant is Resource:
			continue
		var body := body_variant as Resource
		if StringName(body.get("body_id")) == body_id:
			return body
	return null


func _settle_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await process_frame


func _record_check(name: String, ok: bool, evidence: Dictionary) -> void:
	var row := evidence.duplicate(true)
	row["ok"] = ok
	_checks[name] = row
	if not ok:
		_failures.append(name)


func _finish_setup_failure(message: String) -> void:
	_failures.append(message)
	_write_report({
		"schema": "forge_v2_live_handle_noodle_deposition",
		"schema_version": 1,
		"ok": false,
		"checks": _checks,
		"stroke_rows": _stroke_rows,
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
