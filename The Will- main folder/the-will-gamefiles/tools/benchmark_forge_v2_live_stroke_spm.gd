extends SceneTree

const ForgeV2StageControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const ForgeV2WorkspacePreviewScript = preload(
	"res://runtime/forge_v2/forge_v2_workspace_preview.gd"
)
const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2VolumeStrokeScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_stroke.gd"
)
const ForgeV2WorkpieceStressFixtureScript = preload(
	"res://tools/forge_v2_workpiece_stress_fixture.gd"
)
const ForgeV2KeybindingStateScript = preload(
	"res://runtime/forge_v2/forge_v2_keybinding_state.gd"
)
const PlayerToolProfileLibraryStateScript = preload(
	"res://core/models/player_tool_profile_library_state.gd"
)
const CraftingBenchUIV2Scene = preload(
	"res://scenes/ui_v2/crafting_bench_ui_v2.tscn"
)

const SCHEMA_VERSION := 3
const DEFAULT_WINDOW_SECONDS := 60.0
const DEFAULT_STROKE_CAP := 1000
const MAX_RELEASE_READY_SECONDS := 5.0
const STABLE_POSITION_TOLERANCE_METERS := 0.0002
const BOUNDED_TAIL_CAPACITY := 5
const BOUNDED_LOGICAL_BODY_LIMIT := 7
const BOUNDED_NATIVE_STATE_LIMIT := 6
const MATERIAL_SURFACE_COLLISION_LAYER := 1 << 20
const READINESS_PROBE_LANE_CURRENT_STROKE := &"current_stroke"
const READINESS_PROBE_LANE_STABLE_SEED_ANCHOR := &"stable_seed_anchor"
const BENCHMARK_HANDLE_MATERIAL_ID := &"mat_wood_gray"
const RESULT_DIRECTORY := "C:/WORKSPACE/godot_runs"
const LATEST_RESULT_PATH := RESULT_DIRECTORY + "/forge_v2_live_stroke_spm_latest.json"
const LATEST_CSV_PATH := RESULT_DIRECTORY + "/forge_v2_live_stroke_spm_latest.csv"
const LATEST_HEARTBEAT_PATH := RESULT_DIRECTORY + "/forge_v2_live_stroke_spm_latest.heartbeat.txt"
const PROFILE_COPY_FIELDS := [
	"body_kind",
	"material_variant_id",
	"operation_mode",
	"placement_policy",
	"shape_kind",
	"profile_id",
	"profile_display_name",
	"profile_polygon_2d_meters",
	"profile_anchor_2d_meters",
	"profile_contact_point_relative_2d_meters",
	"profile_contact_direction_2d",
	"profile_contact_distance_meters",
	"profile_runtime_schema_version",
	"profile_rotation_bias_degrees",
]

var errors: Array[String] = []
var rows: Array[Dictionary] = []
var result_prefix := ""
var include_full_ui := true
var include_protected_handle := true
var window_seconds := DEFAULT_WINDOW_SECONDS
var stroke_cap := DEFAULT_STROKE_CAP
var workspace_bounds_scale := 1.0
var benchmark_started_usec := 0
var benchmark_deadline_usec := 0
var measurement_finished_usec := 0
var active_elapsed_usec := 0
var initial_memory_bytes := 0
var peak_memory_bytes := 0
var stop_reason := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_DIRECTORY)
	var run_id := _build_run_id()
	result_prefix = RESULT_DIRECTORY + "/forge_v2_live_stroke_spm_" + run_id
	window_seconds = _read_float_environment(
		"FORGE_V2_LIVE_SPM_WINDOW_SECONDS",
		DEFAULT_WINDOW_SECONDS,
		1.0,
		600.0
	)
	stroke_cap = _read_int_environment(
		"FORGE_V2_LIVE_SPM_STROKE_CAP",
		DEFAULT_STROKE_CAP,
		1,
		DEFAULT_STROKE_CAP
	)
	include_full_ui = _read_bool_environment("FORGE_V2_LIVE_SPM_FULL_UI", true)
	include_protected_handle = _read_bool_environment(
		"FORGE_V2_LIVE_SPM_PROTECTED_HANDLE",
		true
	)
	workspace_bounds_scale = _read_float_environment(
		"FORGE_V2_LIVE_SPM_BOUNDS_SCALE",
		1.0,
		1.0,
		10.0
	)
	_write_heartbeat("setup run_id=%s" % run_id)

	# The body Resources and their digest are prepared before the measurement clock.
	var fixture_bodies := _build_fixture_bodies(stroke_cap)
	var preflight_operation_count := maxi(fixture_bodies.size() - 1, 1)
	var fixture_preflight: Dictionary = ForgeV2WorkpieceStressFixtureScript.preflight(
		preflight_operation_count
	) as Dictionary
	if not bool(fixture_preflight.get("ok", false)):
		_fail("stress fixture preflight failed: %s" % str(fixture_preflight.get("errors", [])))
	if fixture_bodies.size() != stroke_cap:
		_fail("fixture body count mismatch")

	var controller: Node = ForgeV2StageControllerScript.new()
	controller.name = "LiveSpmStageController"
	root.add_child(controller)
	controller.call("start_new_draft", "Live Organic CSG SPM Benchmark")

	var harness := await _build_harness(controller, run_id)
	var workspace: Node3D = harness.get("workspace", null) as Node3D
	var ui: CanvasLayer = harness.get("ui", null) as CanvasLayer
	if workspace == null:
		_fail("real Forge V2 workspace could not be constructed")
	var workspace_bounds_override := _apply_test_workspace_bounds_scale(
		controller,
		workspace_bounds_scale
	)
	if not bool(workspace_bounds_override.get("ok", false)):
		_fail("test-only workspace bounds override failed")

	var protected_handle_setup := {
		"ok": true,
		"enabled": include_protected_handle,
		"target_id": StringName(),
	}
	if errors.is_empty() and include_protected_handle:
		protected_handle_setup = await _install_protected_benchmark_handle(
			controller,
			workspace
		)
		if not bool(protected_handle_setup.get("ok", false)):
			_fail(
				"protected benchmark Handle setup failed: %s"
				% String(protected_handle_setup.get("failure", "unknown"))
			)
	if errors.is_empty():
		_configure_controller_for_fixture(controller, fixture_bodies[0])
		await process_frame
	var stable_seed_probe_local := _resolve_probe_local(fixture_bodies[0])

	initial_memory_bytes = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	peak_memory_bytes = initial_memory_bytes
	benchmark_started_usec = Time.get_ticks_usec()
	benchmark_deadline_usec = benchmark_started_usec + int(window_seconds * 1000000.0)
	var previous_target_id := StringName(protected_handle_setup.get(
		"target_id",
		StringName()
	))
	for stroke_zero_index in range(fixture_bodies.size()):
		if not errors.is_empty():
			stop_reason = "preflight_or_bounded_invariant_failed"
			break
		if Time.get_ticks_usec() >= benchmark_deadline_usec:
			stop_reason = "wall_clock_measurement_window_reached"
			break
		var fixture_body: Resource = fixture_bodies[stroke_zero_index] as Resource
		var stroke_result: Dictionary = await _run_one_stroke(
			controller,
			workspace,
			fixture_body,
			stroke_zero_index + 1,
			previous_target_id,
			stable_seed_probe_local
		)
		if not rows.is_empty():
			var previous_row: Dictionary = rows[rows.size() - 1]
			var next_started_usec := int(stroke_result.get("stroke_started_usec", 0))
			var previous_started_usec := int(previous_row.get("stroke_started_usec", 0))
			var previous_ready_usec := int(previous_row.get("stable_ready_usec", 0))
			if next_started_usec > 0 and previous_started_usec > 0 and previous_ready_usec > 0:
				previous_row["next_stroke_started_usec"] = next_started_usec
				previous_row["ready_to_next_stroke_ms"] = (
					float(next_started_usec - previous_ready_usec) / 1000.0
				)
				previous_row["cycle_start_to_next_start_ms"] = (
					float(next_started_usec - previous_started_usec) / 1000.0
				)
				rows[rows.size() - 1] = previous_row
		rows.append(stroke_result)
		active_elapsed_usec += int(stroke_result.get("stroke_total_us", 0))
		peak_memory_bytes = maxi(
			peak_memory_bytes,
			int(stroke_result.get("memory_static_bytes", 0))
		)
		if bool(stroke_result.get("stable_target_ready", false)):
			previous_target_id = StringName(stroke_result.get("target_after", StringName()))
		else:
			stroke_result["target_failure_diagnostics"] = (
				_capture_target_failure_diagnostics(
					workspace,
					fixture_bodies,
					stroke_zero_index
				)
			)
			rows[rows.size() - 1] = stroke_result
			_fail("stroke %d did not become stably targetable" % (stroke_zero_index + 1))
			stop_reason = String(stroke_result.get("failure", "target_readiness_failed"))
			break
		var bounded_invariants := _validate_bounded_stroke_invariants(
			stroke_result,
			stroke_zero_index + 1
		)
		stroke_result["bounded_invariants"] = bounded_invariants
		rows[rows.size() - 1] = stroke_result
		if not bool(bounded_invariants.get("ok", false)):
			_fail(
				"bounded history invariant failed at stroke %d: %s"
				% [
					stroke_zero_index + 1,
					str(bounded_invariants.get("failures", [])),
				]
			)
			stop_reason = "bounded_history_invariant_failed"
			break
		if float(stroke_result.get("release_to_ready_ms", 0.0)) > MAX_RELEASE_READY_SECONDS * 1000.0:
			stop_reason = "single_release_exceeded_%.1fs" % MAX_RELEASE_READY_SECONDS
			break
		if (stroke_zero_index + 1) % 10 == 0:
			_write_heartbeat(
				"stroke=%d active_seconds=%.3f last_ready_ms=%.3f max_ready_ms=%.3f"
				% [
					stroke_zero_index + 1,
					float(active_elapsed_usec) / 1000000.0,
					float(stroke_result.get("release_to_ready_ms", 0.0)),
					_maximum_metric(rows, "release_to_ready_ms"),
				]
			)
	if stop_reason.is_empty():
		stop_reason = (
			"stroke_cap_reached"
			if rows.size() >= stroke_cap
			else "completed"
		)
	measurement_finished_usec = Time.get_ticks_usec()

	var final_target_check := {"ok": false}
	if not rows.is_empty():
		final_target_check = await _capture_stable_target(
			workspace,
			_resolve_probe_local(fixture_bodies[maxi(rows.size() - 1, 0)]),
			StringName(),
			1.0,
			stable_seed_probe_local,
			true
		)
	var workspace_bounds_restore := _restore_test_workspace_bounds(
		controller,
		workspace_bounds_override
	)
	var summary := _build_summary(rows)
	var report := {
		"schema_version": SCHEMA_VERSION,
		"outcome": "pass" if errors.is_empty() else "partial_or_fail",
		"measurement_scope": (
			"actual StageController + full CraftingBench UI/own-world WorkspacePreview + "
			+ "organic static CSG presenter + production collision resolver"
			if include_full_ui
			else "actual StageController + WorkspacePreview + organic static CSG presenter + production collision resolver"
		),
		"primary_metric": "mouse_release_to_new_two-capture_stable_target_ms",
		"tail_priority": "max_then_p99_then_p95; minimum_and_mean_are_secondary",
		"percentile_method": "nearest_rank",
		"run_id": run_id,
		"window_seconds": window_seconds,
		"stroke_cap": stroke_cap,
		"max_single_release_seconds": MAX_RELEASE_READY_SECONDS,
		"stop_reason": stop_reason,
		"fixture_preflight": fixture_preflight,
		"protected_handle_setup": protected_handle_setup,
		"include_full_ui": include_full_ui,
		"include_protected_handle": include_protected_handle,
		"test_workspace_bounds": {
			"requested_scale": workspace_bounds_scale,
			"override": workspace_bounds_override,
			"restore": workspace_bounds_restore,
		},
		"errors": errors,
		"summary": summary,
		"final_target_check": final_target_check,
		"memory": {
			"kind": "sampled Godot MEMORY_STATIC; not process/GPU/continuous peak",
			"initial_bytes": initial_memory_bytes,
			"final_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
			"sampled_peak_bytes": peak_memory_bytes,
		},
		"wall_elapsed_ms": float(measurement_finished_usec - benchmark_started_usec) / 1000.0,
		"active_measured_elapsed_ms": float(active_elapsed_usec) / 1000.0,
		"rows": rows,
		"nonclaims": [
			"This is deterministic engine-capacity SPM, not human drawing speed.",
			"Headless timing is not rendered-editor FPS.",
			(
				"The fixture is one protected Handle plus connected same-material Add/Replace strokes with five exact samples each."
				if include_protected_handle
				else "Diagnostic A/B only: this run omits the protected Handle; connected same-material Add/Replace strokes are unchanged."
			),
			"No static-mesh bake or topology analysis runs inside the timed lane.",
			"A 60-second result is not a defensible extrapolation to stroke 5000.",
		],
	}
	_write_outputs(report)
	_write_heartbeat(
		"done outcome=%s strokes=%d max_ready_ms=%.3f"
		% [report["outcome"], rows.size(), float(summary.get("release_to_ready_max_ms", 0.0))]
	)
	if ui != null and is_instance_valid(ui):
		ui.queue_free()
	quit(0 if errors.is_empty() else 1)


func _build_harness(controller: Node, run_id: String) -> Dictionary:
	if include_full_ui:
		var ui: CanvasLayer = CraftingBenchUIV2Scene.instantiate() as CanvasLayer
		if ui == null:
			return {}
		var profile_state: Resource = PlayerToolProfileLibraryStateScript.new()
		profile_state.set(
			"save_file_path",
			RESULT_DIRECTORY + "/live_spm_%s_profile_library.tres" % run_id
		)
		var keybinding_state: Resource = ForgeV2KeybindingStateScript.new()
		keybinding_state.set(
			"save_file_path",
			RESULT_DIRECTORY + "/live_spm_%s_keybindings.json" % run_id
		)
		keybinding_state.call("normalize")
		ui.set("tool_profile_library_state", profile_state)
		ui.set("keybinding_state", keybinding_state)
		root.add_child(ui)
		await process_frame
		ui.call("open_for", null, controller, "Live Organic CSG SPM Benchmark", null)
		await process_frame
		var workspace: Node3D = ui.get("workspace_preview") as Node3D
		return {"ui": ui, "workspace": workspace}
	var workspace := ForgeV2WorkspacePreviewScript.new()
	workspace.name = "LiveSpmWorkspace"
	root.add_child(workspace)
	workspace.call("bind_stage_controller", controller)
	await process_frame
	return {"ui": null, "workspace": workspace}


func _configure_controller_for_fixture(controller: Node, fixture_body: Resource) -> void:
	controller.call("set_active_material_variant_id", StringName(fixture_body.get("material_variant_id")))
	controller.call("set_active_operation_mode", StringName(fixture_body.get("operation_mode")))
	controller.call("set_placement_policy", StringName(fixture_body.get("placement_policy")))
	var polygon: PackedVector2Array = fixture_body.get("profile_polygon_2d_meters")
	var profile_data := ForgeV2ProfileShapeLibraryScript.compile_basic_profile_runtime_data({
		"profile_id": StringName(fixture_body.get("profile_id")),
		"id": StringName(fixture_body.get("profile_id")),
		"label": String(fixture_body.get("profile_display_name")),
		"family": ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC,
		"base_polygon_2d_meters": polygon,
		"polygon_2d_meters": polygon,
		"base_anchor_2d_meters": fixture_body.get("profile_anchor_2d_meters"),
		"rotation_degrees": float(fixture_body.get("profile_rotation_bias_degrees")),
	})
	if not bool(controller.call("select_active_saved_basic_profile", profile_data)):
		_fail("fixture profile could not be selected")


func _apply_test_workspace_bounds_scale(
	controller: Node,
	scale: float
) -> Dictionary:
	if controller == null or not controller.has_method("get_workspace_contract"):
		return {"ok": false, "reason": "workspace_contract_unavailable"}
	var contract := controller.call("get_workspace_contract") as Resource
	if contract == null:
		return {"ok": false, "reason": "workspace_contract_missing"}
	var original_min := contract.get("local_min") as Vector3
	var original_max := contract.get("local_max") as Vector3
	var original_fit_size := float(contract.get("fit_size_meters"))
	var normalized_scale := clampf(scale, 1.0, 10.0)
	var center := (original_min + original_max) * 0.5
	var half_size := (original_max - original_min) * 0.5
	var effective_min := center - (half_size * normalized_scale)
	var effective_max := center + (half_size * normalized_scale)
	contract.set("local_min", effective_min)
	contract.set("local_max", effective_max)
	return {
		"ok": true,
		"applied": normalized_scale > 1.0,
		"scale": normalized_scale,
		"original_min": original_min,
		"original_max": original_max,
		"original_fit_size_meters": original_fit_size,
		"effective_min": effective_min,
		"effective_max": effective_max,
	}


func _restore_test_workspace_bounds(
	controller: Node,
	override: Dictionary
) -> Dictionary:
	if controller == null or not controller.has_method("get_workspace_contract"):
		return {"ok": false, "reason": "workspace_contract_unavailable"}
	var contract := controller.call("get_workspace_contract") as Resource
	if contract == null or not bool(override.get("ok", false)):
		return {"ok": false, "reason": "workspace_bounds_override_missing"}
	var original_min := override.get("original_min", Vector3.ZERO) as Vector3
	var original_max := override.get("original_max", Vector3.ZERO) as Vector3
	var original_fit_size := float(override.get(
		"original_fit_size_meters",
		6.0
	))
	contract.set("local_min", original_min)
	contract.set("local_max", original_max)
	contract.set("fit_size_meters", original_fit_size)
	return {
		"ok": (
			(contract.get("local_min") as Vector3).is_equal_approx(original_min)
			and (contract.get("local_max") as Vector3).is_equal_approx(original_max)
			and is_equal_approx(
				float(contract.get("fit_size_meters")),
				original_fit_size
			)
		),
		"restored_min": contract.get("local_min"),
		"restored_max": contract.get("local_max"),
		"restored_fit_size_meters": float(contract.get("fit_size_meters")),
	}


func _install_protected_benchmark_handle(
	controller: Node,
	workspace: Node3D
) -> Dictionary:
	var state := controller.call("get_active_authoring_state") as Resource
	if state == null:
		return {"ok": false, "failure": "authoring_state_missing"}
	var handle := _build_protected_benchmark_handle()
	var bodies: Array[Resource] = state.get("material_bodies") as Array[Resource]
	bodies.append(handle)
	state.set("material_bodies", bodies)
	var handle_layer := state.call(
		"commit_material_body_as_layer",
		StringName(handle.get("body_id"))
	) as Resource
	if handle_layer == null:
		return {"ok": false, "failure": "handle_commit_rejected"}
	controller.call("_emit_state_changed")
	var handle_points: PackedVector3Array = handle.get("path_points")
	var handle_probe := handle_points[int(handle_points.size() / 2)]
	var readiness := await _capture_stable_target(
		workspace,
		handle_probe,
		StringName(),
		MAX_RELEASE_READY_SECONDS
	)
	if not bool(readiness.get("ok", false)):
		return {
			"ok": false,
			"failure": String(readiness.get(
				"failure",
				"handle_target_not_ready"
			)),
		}
	var presenter: Node = workspace.get("volume_preview_presenter") as Node
	var native_diagnostics := {}
	if (
		presenter != null
		and presenter.has_method("get_native_static_sync_diagnostics")
	):
		native_diagnostics = presenter.call(
			"get_native_static_sync_diagnostics"
		) as Dictionary
	var bounded_diagnostics := _capture_bounded_history_diagnostics(state)
	var target_id := StringName(readiness.get(
		"target_id",
		StringName()
	))
	var setup_ok := (
		target_id != StringName()
		and int(bounded_diagnostics.get("protected_body_count", 0)) == 1
		and int(bounded_diagnostics.get("logical_body_count", 0)) == 1
		and int(bounded_diagnostics.get("checkpoint_operation_count", -1)) == 0
		and int(bounded_diagnostics.get("active_tail_layer_count", -1)) == 0
		and String(native_diagnostics.get("last_mode", ""))
		== "protected_changed"
		and bool(native_diagnostics.get("authoritative", false))
		and not bool(native_diagnostics.get("publication_pending", true))
		and int(native_diagnostics.get("fallback_count", -1)) == 0
	)
	return {
		"ok": setup_ok,
		"failure": "" if setup_ok else "protected_handle_contract_mismatch",
		"body_id": String(handle.get("body_id")),
		"layer_id": String(handle_layer.get("layer_id")),
		"material_variant_id": String(handle.get("material_variant_id")),
		"target_id": String(target_id),
		"logical_body_count": int(bounded_diagnostics.get(
			"logical_body_count",
			0
		)),
		"native_mode": String(native_diagnostics.get("last_mode", "")),
	}


func _build_protected_benchmark_handle() -> Resource:
	var body: Resource = ForgeV2MaterialBodyScript.new()
	var center_y := -0.20
	var center_z := -0.198
	body.set("body_id", &"live_spm_protected_handle")
	body.set("source_record_id", &"live_spm_protected_handle_command")
	body.set(
		"body_kind",
		ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE
	)
	body.set("material_variant_id", BENCHMARK_HANDLE_MATERIAL_ID)
	body.set(
		"operation_mode",
		ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL
	)
	body.set(
		"placement_policy",
		ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
	)
	body.set("shape_kind", ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH)
	body.set("path_points", PackedVector3Array([
		Vector3(-0.36, center_y, center_z),
		Vector3(-0.18, center_y, center_z),
	]))
	body.set("path_surface_normals", PackedVector3Array([
		Vector3.BACK,
		Vector3.BACK,
	]))
	body.set("path_contact_directions", PackedVector3Array([
		Vector3.FORWARD,
		Vector3.FORWARD,
	]))
	body.set("profile_id", &"live_spm_protected_handle_rectangle")
	body.set("profile_display_name", "Live SPM protected Handle")
	body.set("profile_polygon_2d_meters", PackedVector2Array([
		Vector2(-0.018, -0.014),
		Vector2(0.018, -0.014),
		Vector2(0.018, 0.014),
		Vector2(-0.018, 0.014),
	]))
	body.set("profile_anchor_2d_meters", Vector2.ZERO)
	body.set(
		"profile_contact_point_relative_2d_meters",
		Vector2(0.0, -0.014)
	)
	body.set("profile_contact_direction_2d", Vector2.DOWN)
	body.set("profile_contact_distance_meters", 0.014)
	body.set("profile_runtime_schema_version", 1)
	body.set("profile_rotation_bias_degrees", 0.0)
	body.set("created_timestamp", 1700001000.0)
	body.set("updated_timestamp", 1700001000.0)
	body.call("normalize")
	body.set("body_id", &"live_spm_protected_handle")
	body.set("source_record_id", &"live_spm_protected_handle_command")
	return body


func _run_one_stroke(
	controller: Node,
	workspace: Node3D,
	fixture_body: Resource,
	stroke_number: int,
	previous_target_id: StringName,
	stable_seed_probe_local: Vector3
) -> Dictionary:
	var path_points: PackedVector3Array = fixture_body.get("path_points")
	var normals: PackedVector3Array = fixture_body.get("path_surface_normals")
	var contacts: PackedVector3Array = fixture_body.get("path_contact_directions")
	var stroke_started := Time.get_ticks_usec()
	var body_id: StringName = controller.call(
		"begin_material_body_path",
		path_points[0],
		normals[0],
		contacts[0]
	)
	if body_id == StringName():
		return _failed_row(stroke_number, "begin_rejected", stroke_started)
	var authoring_state := controller.call(
		"get_active_authoring_state"
	) as Resource
	var active_body := _find_body(authoring_state, body_id)
	if active_body == null:
		return _failed_row(stroke_number, "active_body_missing", stroke_started)
	for field_name: String in PROFILE_COPY_FIELDS:
		active_body.set(field_name, fixture_body.get(field_name))
	var accepted_count := int(controller.call(
		"extend_material_body_path_samples",
		path_points.slice(1),
		normals.slice(1),
		true,
		contacts.slice(1)
	))
	if accepted_count != path_points.size() - 1:
		return _failed_row(stroke_number, "sample_batch_rejected", stroke_started)
	var release_started := Time.get_ticks_usec()
	var committed := bool(controller.call(
		"finish_material_body_path",
		Vector3.ZERO,
		false,
		Vector3.FORWARD
	))
	var finish_return_usec := Time.get_ticks_usec()
	var finish_ms := float(finish_return_usec - release_started) / 1000.0
	if not committed:
		return _failed_row(stroke_number, "finish_rejected", stroke_started, release_started)
	var current_stroke_probe_local := _resolve_probe_local(fixture_body)
	var readiness: Dictionary = await _capture_stable_target(
		workspace,
		current_stroke_probe_local,
		previous_target_id,
		MAX_RELEASE_READY_SECONDS - finish_ms / 1000.0,
		stable_seed_probe_local,
		true
	)
	var ready_usec := int(readiness.get("stable_target_usec", Time.get_ticks_usec()))
	var first_target_usec := int(readiness.get("first_new_target_usec", 0))
	var target_after := StringName(readiness.get("target_id", StringName()))
	var current_probe_instantaneous := _capture_instantaneous_current_probe(
		workspace,
		current_stroke_probe_local,
		previous_target_id,
		target_after
	)
	var memory_bytes := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var native_diagnostics := {}
	var presenter: Node = workspace.get("volume_preview_presenter") as Node
	if (
		presenter != null
		and presenter.has_method("get_native_static_sync_diagnostics")
	):
		native_diagnostics = presenter.call(
			"get_native_static_sync_diagnostics"
		) as Dictionary
	var bounded_diagnostics := _capture_bounded_history_diagnostics(
		authoring_state
	)
	return {
		"stroke": stroke_number,
		"fixture_body_id": String(fixture_body.get("body_id")),
		"fixture_grid_row": int((stroke_number - 1) / 101),
		"fixture_grid_column_in_row": int((stroke_number - 1) % 101),
		"path_reversed": (stroke_number - 1) % 2 == 1,
		"committed": committed,
		"stable_target_ready": bool(readiness.get("ok", false)),
		"failure": String(readiness.get("failure", "")),
		"readiness_probe_lane": String(readiness.get(
			"readiness_probe_lane",
			StringName()
		)),
		"current_probe_instantaneous": current_probe_instantaneous,
		"current_probe_instantaneous_new_target_ready": bool(
			current_probe_instantaneous.get("new_target_ready", false)
		),
		"current_probe_instantaneous_target_id": String(
			current_probe_instantaneous.get("target_id", StringName())
		),
		"stroke_started_usec": stroke_started,
		"stroke_started_offset_ms": float(stroke_started - benchmark_started_usec) / 1000.0,
		"release_started_usec": release_started,
		"release_started_offset_ms": float(release_started - benchmark_started_usec) / 1000.0,
		"finish_return_usec": finish_return_usec,
		"finish_return_offset_ms": float(finish_return_usec - benchmark_started_usec) / 1000.0,
		"first_new_target_usec": first_target_usec,
		"first_new_target_offset_ms": (
			float(first_target_usec - benchmark_started_usec) / 1000.0
			if first_target_usec > 0 else 0.0
		),
		"stable_ready_usec": ready_usec,
		"stable_ready_offset_ms": float(ready_usec - benchmark_started_usec) / 1000.0,
		"input_to_release_ms": float(release_started - stroke_started) / 1000.0,
		"finish_call_ms": finish_ms,
		"finish_to_first_target_ms": (
			float(first_target_usec - finish_return_usec) / 1000.0
			if first_target_usec > 0 else 0.0
		),
		"first_target_to_stable_ms": (
			float(ready_usec - first_target_usec) / 1000.0
			if first_target_usec > 0 else 0.0
		),
		"first_new_target_ms": (
			float(first_target_usec - release_started) / 1000.0
			if first_target_usec > 0 else 0.0
		),
		"release_to_ready_ms": float(ready_usec - release_started) / 1000.0,
		"post_finish_ready_ms": float(ready_usec - finish_return_usec) / 1000.0,
		"stroke_total_ms": float(ready_usec - stroke_started) / 1000.0,
		"stroke_total_us": ready_usec - stroke_started,
		"frames_to_ready": int(readiness.get("frames", 0)),
		"max_wait_frame_gap_ms": float(readiness.get("max_frame_gap_ms", 0.0)),
		"target_before": String(previous_target_id),
		"target_after": String(target_after),
		"target_changed": target_after != StringName() and target_after != previous_target_id,
		"hit_position": readiness.get("position", Vector3.ZERO),
		"hit_normal": readiness.get("normal", Vector3.ZERO),
		"memory_static_bytes": memory_bytes,
		"native_static_diagnostics": native_diagnostics,
		"bounded_history_diagnostics": bounded_diagnostics,
		"bounded_checkpoint_operation_count": int(
			bounded_diagnostics.get("checkpoint_operation_count", 0)
		),
		"bounded_active_tail_layer_count": int(
			bounded_diagnostics.get("active_tail_layer_count", 0)
		),
		"bounded_protected_body_count": int(
			bounded_diagnostics.get("protected_body_count", 0)
		),
		"bounded_logical_body_count": int(
			bounded_diagnostics.get("logical_body_count", 0)
		),
		"bounded_checkpoint_mesh_dirty": bool(
			bounded_diagnostics.get("checkpoint_mesh_dirty", false)
		),
		"bounded_recovery_blocked": bool(
			bounded_diagnostics.get("recovery_blocked", false)
		),
		"bounded_history_enabled": bool(
			bounded_diagnostics.get("bounded_history_enabled", false)
		),
		"bounded_pending_native_ack": bool(
			bounded_diagnostics.get("pending_native_ack", false)
		),
		"native_retained_state_count": int(
			native_diagnostics.get("retained_state_count", 0)
		),
		"native_boolean_count": int(
			native_diagnostics.get("boolean_count", 0)
		),
		"native_export_count": int(
			native_diagnostics.get("export_count", 0)
		),
		"native_checkpoint_materialization_attempt_count": int(
			native_diagnostics.get(
				"checkpoint_materialization_attempt_count",
				0
			)
		),
		"native_checkpoint_materialization_count": int(
			native_diagnostics.get("checkpoint_materialization_count", 0)
		),
		"native_fallback_count": int(
			native_diagnostics.get("fallback_count", 0)
		),
		"native_prefix_body_count": int(
			native_diagnostics.get("prefix_body_count", 0)
		),
	}


func _capture_stable_target(
	workspace: Node3D,
	target_local: Vector3,
	forbidden_target_id: StringName,
	remaining_seconds: float,
	stable_anchor_local: Vector3 = Vector3.ZERO,
	use_stable_anchor: bool = false
) -> Dictionary:
	if remaining_seconds <= 0.0:
		return {"ok": false, "failure": "finish_call_exceeded_release_limit"}
	var wait_started := Time.get_ticks_usec()
	var deadline_usec := wait_started + int(remaining_seconds * 1000000.0)
	var previous_current_hit: Dictionary = {}
	var previous_anchor_hit: Dictionary = {}
	var current_first_new_target_usec := 0
	var anchor_first_new_target_usec := 0
	var frames := 0
	var max_frame_gap_ms := 0.0
	var previous_frame_tick := wait_started
	while Time.get_ticks_usec() < deadline_usec:
		await process_frame
		var after_process := Time.get_ticks_usec()
		max_frame_gap_ms = maxf(
			max_frame_gap_ms,
			float(after_process - previous_frame_tick) / 1000.0
		)
		previous_frame_tick = after_process
		await physics_frame
		var after_physics := Time.get_ticks_usec()
		max_frame_gap_ms = maxf(
			max_frame_gap_ms,
			float(after_physics - previous_frame_tick) / 1000.0
		)
		previous_frame_tick = after_physics
		frames += 1
		var current_hit := _capture_target_hit(workspace, target_local)
		var current_target_id := StringName(current_hit.get(
			"surface_target_id",
			StringName()
		))
		if _target_hit_is_new_and_valid(current_hit, forbidden_target_id):
			if current_first_new_target_usec == 0:
				current_first_new_target_usec = Time.get_ticks_usec()
			if (
				not previous_current_hit.is_empty()
				and _hits_are_stable(previous_current_hit, current_hit)
			):
				var stable_target_usec := Time.get_ticks_usec()
				return _build_stable_target_capture(
					current_hit,
					current_target_id,
					READINESS_PROBE_LANE_CURRENT_STROKE,
					frames,
					wait_started,
					current_first_new_target_usec,
					stable_target_usec,
					max_frame_gap_ms,
					current_first_new_target_usec,
					anchor_first_new_target_usec
				)
			previous_current_hit = current_hit
		else:
			previous_current_hit = {}
		if not use_stable_anchor:
			continue
		var anchor_hit := _capture_target_hit(workspace, stable_anchor_local)
		var anchor_target_id := StringName(anchor_hit.get(
			"surface_target_id",
			StringName()
		))
		if not _target_hit_is_new_and_valid(anchor_hit, forbidden_target_id):
			previous_anchor_hit = {}
			continue
		if anchor_first_new_target_usec == 0:
			anchor_first_new_target_usec = Time.get_ticks_usec()
		if (
			not previous_anchor_hit.is_empty()
			and _hits_are_stable(previous_anchor_hit, anchor_hit)
		):
			var stable_target_usec := Time.get_ticks_usec()
			return _build_stable_target_capture(
				anchor_hit,
				anchor_target_id,
				READINESS_PROBE_LANE_STABLE_SEED_ANCHOR,
				frames,
				wait_started,
				anchor_first_new_target_usec,
				stable_target_usec,
				max_frame_gap_ms,
				current_first_new_target_usec,
				anchor_first_new_target_usec
			)
		previous_anchor_hit = anchor_hit
	var first_new_target_usec := _earliest_positive_usec(
		current_first_new_target_usec,
		anchor_first_new_target_usec
	)
	return {
		"ok": false,
		"failure": "new_target_not_stable_within_limit",
		"frames": frames,
		"readiness_probe_lane": StringName(),
		"first_new_target_us": (
			first_new_target_usec - wait_started
			if first_new_target_usec > 0 else 0
		),
		"first_new_target_usec": first_new_target_usec,
		"current_first_new_target_usec": current_first_new_target_usec,
		"anchor_first_new_target_usec": anchor_first_new_target_usec,
		"max_frame_gap_ms": max_frame_gap_ms,
	}


func _target_hit_is_new_and_valid(
	hit: Dictionary,
	forbidden_target_id: StringName
) -> bool:
	var target_id := StringName(hit.get("surface_target_id", StringName()))
	return (
		bool(hit.get("valid", false))
		and target_id != StringName()
		and target_id != forbidden_target_id
	)


func _build_stable_target_capture(
	hit: Dictionary,
	target_id: StringName,
	probe_lane: StringName,
	frames: int,
	wait_started_usec: int,
	first_new_target_usec: int,
	stable_target_usec: int,
	max_frame_gap_ms: float,
	current_first_new_target_usec: int,
	anchor_first_new_target_usec: int
) -> Dictionary:
	return {
		"ok": true,
		"target_id": target_id,
		"position": hit.get("local_position", Vector3.ZERO),
		"normal": hit.get("local_normal", Vector3.ZERO),
		"frames": frames,
		"readiness_probe_lane": probe_lane,
		"first_new_target_us": first_new_target_usec - wait_started_usec,
		"first_new_target_usec": first_new_target_usec,
		"stable_target_usec": stable_target_usec,
		"max_frame_gap_ms": max_frame_gap_ms,
		"current_first_new_target_usec": current_first_new_target_usec,
		"anchor_first_new_target_usec": anchor_first_new_target_usec,
	}


func _earliest_positive_usec(first: int, second: int) -> int:
	if first <= 0:
		return maxi(second, 0)
	if second <= 0:
		return first
	return mini(first, second)


func _capture_instantaneous_current_probe(
	workspace: Node3D,
	target_local: Vector3,
	forbidden_target_id: StringName,
	ready_target_id: StringName
) -> Dictionary:
	var hit := _capture_target_hit(workspace, target_local)
	var target_id := StringName(hit.get("surface_target_id", StringName()))
	var valid := bool(hit.get("valid", false))
	var new_target_ready := (
		valid
		and target_id != StringName()
		and target_id != forbidden_target_id
	)
	var miss_reason := ""
	if hit.is_empty():
		miss_reason = "projection_or_resolver_empty"
	elif not valid:
		miss_reason = String(hit.get("reject_reason", "resolver_rejected"))
	elif target_id == StringName():
		miss_reason = "surface_target_id_empty"
	elif target_id == forbidden_target_id:
		miss_reason = "previous_revision_target"
	return {
		"captured_usec": Time.get_ticks_usec(),
		"valid": valid,
		"new_target_ready": new_target_ready,
		"target_id": target_id,
		"matches_ready_target": (
			new_target_ready
			and ready_target_id != StringName()
			and target_id == ready_target_id
		),
		"miss_reason": miss_reason,
		"position": hit.get("local_position", Vector3.ZERO),
		"normal": hit.get("local_normal", Vector3.ZERO),
	}


func _capture_target_hit(workspace: Node3D, target_local: Vector3) -> Dictionary:
	var projection: Dictionary = workspace.call(
		"project_workspace_local_to_screen",
		target_local
	) as Dictionary
	if not bool(projection.get("valid", false)):
		return {}
	return workspace.call(
		"resolve_material_surface_target",
		projection.get("screen_position", Vector2.ZERO) as Vector2
	) as Dictionary


func _capture_target_failure_diagnostics(
	workspace: Node3D,
	fixture_bodies: Array,
	failing_fixture_index: int
) -> Dictionary:
	var probes: Array[Dictionary] = []
	_append_target_failure_probe(
		probes,
		workspace,
		"failing_fixture_probe",
		_resolve_fixture_probe_at(fixture_bodies, failing_fixture_index),
		_resolve_fixture_body_id_at(fixture_bodies, failing_fixture_index)
	)
	_append_target_failure_probe(
		probes,
		workspace,
		"previous_fixture_probe",
		_resolve_fixture_probe_at(fixture_bodies, failing_fixture_index - 1),
		_resolve_fixture_body_id_at(fixture_bodies, failing_fixture_index - 1)
	)
	_append_target_failure_probe(
		probes,
		workspace,
		"seed_known_probe",
		_resolve_fixture_probe_at(fixture_bodies, 0),
		_resolve_fixture_body_id_at(fixture_bodies, 0)
	)
	if include_protected_handle:
		var handle := _build_protected_benchmark_handle()
		_append_target_failure_probe(
			probes,
			workspace,
			"protected_handle_probe",
			_resolve_probe_local(handle),
			String(handle.get("body_id"))
		)
	return {
		"captured_after_target_timeout": true,
		"captured_usec": Time.get_ticks_usec(),
		"failing_fixture_index": failing_fixture_index,
		"failing_stroke": failing_fixture_index + 1,
		"workspace_contract": _capture_failure_workspace_contract(workspace),
		"published_revision": _capture_published_revision_diagnostics(workspace),
		"probes": probes,
	}


func _append_target_failure_probe(
	probes: Array[Dictionary],
	workspace: Node3D,
	probe_name: String,
	target_local: Vector3,
	fixture_body_id: String
) -> void:
	var projection := workspace.call(
		"project_workspace_local_to_screen",
		target_local
	) as Dictionary
	var projection_valid := bool(projection.get("valid", false))
	var screen_position := projection.get(
		"screen_position",
		Vector2.ZERO
	) as Vector2
	var resolver_result := {}
	if projection_valid:
		resolver_result = workspace.call(
			"resolve_material_surface_target",
			screen_position
		) as Dictionary
	probes.append({
		"name": probe_name,
		"fixture_body_id": fixture_body_id,
		"target_local": target_local,
		"projection": _sanitize_projection_result(projection),
		"resolver": _sanitize_surface_target_result(resolver_result),
		"direct_ray_front_faces_only": (
			_capture_direct_material_ray(workspace, screen_position, false)
			if projection_valid else {"hit": false, "reason": "projection_invalid"}
		),
		"direct_ray_with_back_faces": (
			_capture_direct_material_ray(workspace, screen_position, true)
			if projection_valid else {"hit": false, "reason": "projection_invalid"}
		),
	})


func _resolve_fixture_probe_at(fixture_bodies: Array, index: int) -> Vector3:
	if index < 0 or index >= fixture_bodies.size():
		return Vector3.ZERO
	var body := fixture_bodies[index] as Resource
	return _resolve_probe_local(body)


func _resolve_fixture_body_id_at(fixture_bodies: Array, index: int) -> String:
	if index < 0 or index >= fixture_bodies.size():
		return ""
	var body := fixture_bodies[index] as Resource
	return String(body.get("body_id")) if body != null else ""


func _sanitize_projection_result(projection: Dictionary) -> Dictionary:
	var result := {
		"valid": bool(projection.get("valid", false)),
		"reject_reason": String(projection.get("reject_reason", "")),
	}
	for key: String in [
		"local_position",
		"world_position",
		"screen_position",
	]:
		if projection.has(key):
			result[key] = projection[key]
	return result


func _sanitize_surface_target_result(target: Dictionary) -> Dictionary:
	if target.is_empty():
		return {"valid": false, "empty": true}
	var result := {
		"valid": bool(target.get("valid", false)),
		"reject_reason": String(target.get("reject_reason", "")),
		"target_kind": String(target.get("target_kind", "")),
		"surface_target_id": String(target.get("surface_target_id", "")),
		"source_body_id": String(target.get("source_body_id", "")),
		"source_record_id": String(target.get("source_record_id", "")),
	}
	for key: String in [
		"local_position",
		"world_position",
		"raw_local_position",
		"raw_world_position",
		"local_normal",
		"world_normal",
		"ray_origin",
		"ray_direction",
		"hit_distance",
		"is_clamped",
	]:
		if target.has(key):
			result[key] = target[key]
	result["collider"] = _capture_collider_identity(
		target.get("collider", null) as Object
	)
	return result


func _capture_direct_material_ray(
	workspace: Node3D,
	screen_position: Vector2,
	hit_back_faces: bool
) -> Dictionary:
	var camera := workspace.get("camera") as Camera3D
	if camera == null or not is_instance_valid(camera):
		return {"hit": false, "reason": "camera_missing"}
	var world_3d := workspace.get_world_3d()
	if world_3d == null:
		return {"hit": false, "reason": "world_3d_missing"}
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position).normalized()
	var ray_end := ray_origin + ray_direction * maxf(camera.far, 1.0)
	var ray_query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_end,
		MATERIAL_SURFACE_COLLISION_LAYER
	)
	ray_query.collide_with_areas = false
	ray_query.collide_with_bodies = true
	ray_query.hit_back_faces = hit_back_faces
	ray_query.hit_from_inside = false
	var hit := world_3d.direct_space_state.intersect_ray(ray_query)
	var result := {
		"hit": not hit.is_empty(),
		"hit_back_faces": hit_back_faces,
		"collision_mask": MATERIAL_SURFACE_COLLISION_LAYER,
		"ray_origin": ray_origin,
		"ray_direction": ray_direction,
		"ray_end": ray_end,
	}
	if hit.is_empty():
		return result
	for key: String in ["position", "normal", "face_index", "shape"]:
		if hit.has(key):
			result[key] = hit[key]
	if hit.has("rid"):
		result["rid"] = str(hit["rid"])
	result["collider"] = _capture_collider_identity(
		hit.get("collider", null) as Object
	)
	return result


func _capture_collider_identity(collider: Object) -> Dictionary:
	if collider == null or not is_instance_valid(collider):
		return {"present": false}
	var result := {
		"present": true,
		"class": collider.get_class(),
		"instance_id": collider.get_instance_id(),
	}
	if collider is Node:
		var node := collider as Node
		result["name"] = node.name
		result["path"] = String(node.get_path()) if node.is_inside_tree() else ""
		result["inside_tree"] = node.is_inside_tree()
	if collider is CollisionObject3D:
		var collision_object := collider as CollisionObject3D
		result["collision_layer"] = collision_object.collision_layer
		result["collision_mask"] = collision_object.collision_mask
		result["rid"] = str(collision_object.get_rid())
	for meta_key: StringName in [
		&"forge_v2_material_surface",
		&"forge_v2_material_variant_id",
		&"forge_v2_body_id",
		&"forge_v2_surface_target_id",
		&"forge_v2_publication_pending",
		&"forge_v2_native_revision",
	]:
		if collider.has_meta(meta_key):
			result[String(meta_key)] = collider.get_meta(meta_key)
	return result


func _capture_failure_workspace_contract(workspace: Node3D) -> Dictionary:
	var contract := workspace.get("workspace_contract") as Resource
	if contract == null:
		return {"available": false}
	var local_min := contract.get("local_min") as Vector3
	var local_max := contract.get("local_max") as Vector3
	return {
		"available": true,
		"local_min": local_min,
		"local_max": local_max,
		"local_size": local_max - local_min,
		"fit_size_meters": float(contract.get("fit_size_meters")),
	}


func _capture_published_revision_diagnostics(workspace: Node3D) -> Dictionary:
	var presenter := workspace.get("volume_preview_presenter") as Node
	if presenter == null or not is_instance_valid(presenter):
		return {"available": false, "reason": "presenter_missing"}
	var result := {
		"available": true,
		"presenter_inside_tree": presenter.is_inside_tree(),
	}
	if presenter.has_method("get_native_static_sync_diagnostics"):
		var native_diagnostics := presenter.call(
			"get_native_static_sync_diagnostics"
		) as Dictionary
		for key: String in [
			"authoritative",
			"expected_revision",
			"published_revision",
			"staged_revision",
			"publication_pending",
			"publication_count",
			"last_failure_reason",
			"protected_live_combined_collision",
			"protected_live_combined_triangles",
			"protected_live_combined_vertices",
		]:
			result[key] = native_diagnostics.get(key)
	var revision_node := presenter.get("native_static_published_node") as Node3D
	if revision_node == null or not is_instance_valid(revision_node):
		result["node_present"] = false
		return result
	result["node_present"] = true
	result["node_name"] = revision_node.name
	result["node_path"] = (
		String(revision_node.get_path()) if revision_node.is_inside_tree() else ""
	)
	result["node_inside_tree"] = revision_node.is_inside_tree()
	result["node_visible"] = revision_node.visible
	for meta_key: StringName in [
		&"forge_v2_native_revision",
		&"forge_v2_native_revision_kind",
		&"forge_v2_surface_target_id",
		&"forge_v2_publication_pending",
		&"forge_v2_material_surface",
		&"forge_v2_native_expected_surface_count",
		&"forge_v2_native_ordinary_triangle_count",
		&"forge_v2_native_protected_triangle_count",
		&"forge_v2_native_subtraction_triangle_count",
	]:
		if revision_node.has_meta(meta_key):
			result[String(meta_key)] = revision_node.get_meta(meta_key)
	var mesh_instance := revision_node.get_node_or_null(
		"NativeStaticMaterialBodyMesh"
	) as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		var mesh_aabb := mesh_instance.mesh.get_aabb()
		result["render_mesh_surface_count"] = mesh_instance.mesh.get_surface_count()
		result["render_mesh_aabb_position"] = mesh_aabb.position
		result["render_mesh_aabb_size"] = mesh_aabb.size
	var collision_body := revision_node.get_node_or_null(
		"NativeStaticMaterialBodyCollision"
	) as StaticBody3D
	result["collision_body"] = _capture_collider_identity(collision_body)
	result["collision_shapes"] = _capture_collision_shape_diagnostics(
		collision_body,
		workspace
	)
	return result


func _capture_collision_shape_diagnostics(
	root_node: Node,
	workspace: Node3D
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if root_node == null or not is_instance_valid(root_node):
		return result
	var pending: Array[Node] = [root_node]
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		for child: Node in node.get_children():
			pending.append(child)
		var collision_shape := node as CollisionShape3D
		if collision_shape == null:
			continue
		var shape := collision_shape.shape
		var shape_result := {
			"name": collision_shape.name,
			"path": (
				String(collision_shape.get_path())
				if collision_shape.is_inside_tree() else ""
			),
			"inside_tree": collision_shape.is_inside_tree(),
			"disabled": collision_shape.disabled,
			"shape_present": shape != null,
		}
		if shape != null:
			shape_result["shape_class"] = shape.get_class()
			shape_result["shape_rid"] = str(shape.get_rid())
		if shape is ConcavePolygonShape3D:
			shape_result.merge(
				_analyze_concave_shape_faces(
					shape as ConcavePolygonShape3D,
					collision_shape,
					workspace
				),
				true
			)
		result.append(shape_result)
	return result


func _analyze_concave_shape_faces(
	shape: ConcavePolygonShape3D,
	shape_node: CollisionShape3D,
	workspace: Node3D
) -> Dictionary:
	var faces := shape.get_faces()
	var nonfinite_vertex_count := 0
	var degenerate_triangle_count := 0
	var has_bounds := false
	var local_min := Vector3.ZERO
	var local_max := Vector3.ZERO
	var workspace_min := Vector3.ZERO
	var workspace_max := Vector3.ZERO
	for face_index in range(faces.size()):
		var face_point := faces[face_index]
		if not face_point.is_finite():
			nonfinite_vertex_count += 1
			continue
		var world_point := shape_node.to_global(face_point)
		var workspace_point := workspace.to_local(world_point)
		if not has_bounds:
			local_min = face_point
			local_max = face_point
			workspace_min = workspace_point
			workspace_max = workspace_point
			has_bounds = true
		else:
			local_min = local_min.min(face_point)
			local_max = local_max.max(face_point)
			workspace_min = workspace_min.min(workspace_point)
			workspace_max = workspace_max.max(workspace_point)
	for triangle_offset in range(0, faces.size() - 2, 3):
		var a := faces[triangle_offset]
		var b := faces[triangle_offset + 1]
		var c := faces[triangle_offset + 2]
		if (
			not a.is_finite()
			or not b.is_finite()
			or not c.is_finite()
			or (b - a).cross(c - a).length_squared() <= 1.0e-18
		):
			degenerate_triangle_count += 1
	var result := {
		"backface_collision": shape.backface_collision,
		"face_vertex_count": faces.size(),
		"triangle_count": faces.size() / 3,
		"face_count_multiple_of_three": faces.size() % 3 == 0,
		"nonfinite_vertex_count": nonfinite_vertex_count,
		"degenerate_triangle_count": degenerate_triangle_count,
		"bounds_available": has_bounds,
	}
	if has_bounds:
		result["shape_local_aabb_position"] = local_min
		result["shape_local_aabb_size"] = local_max - local_min
		result["workspace_local_aabb_position"] = workspace_min
		result["workspace_local_aabb_size"] = workspace_max - workspace_min
	return result


func _hits_are_stable(first: Dictionary, second: Dictionary) -> bool:
	return (
		StringName(first.get("surface_target_id", StringName()))
		== StringName(second.get("surface_target_id", StringName()))
		and (first.get("local_position", Vector3.ZERO) as Vector3).distance_to(
			second.get("local_position", Vector3.ZERO) as Vector3
		) <= STABLE_POSITION_TOLERANCE_METERS
		and (first.get("local_normal", Vector3.ZERO) as Vector3).dot(
			second.get("local_normal", Vector3.ZERO) as Vector3
		) >= 0.999
	)


func _resolve_probe_local(body: Resource) -> Vector3:
	var points: PackedVector3Array = body.get("path_points")
	return points[int(points.size() / 2)] if not points.is_empty() else Vector3.ZERO


func _find_body(authoring_state: Resource, body_id: StringName) -> Resource:
	if authoring_state == null:
		return null
	var bodies: Array = authoring_state.get("material_bodies") as Array
	for body_variant: Variant in bodies:
		if body_variant is Resource:
			var body := body_variant as Resource
			if StringName(body.get("body_id")) == body_id:
				return body
	return null


func _capture_bounded_history_diagnostics(
	authoring_state: Resource
) -> Dictionary:
	if (
		authoring_state == null
		or not authoring_state.has_method(
			"get_bounded_presentation_descriptor"
		)
	):
		return {"available": false}
	var descriptor := authoring_state.call(
		"get_bounded_presentation_descriptor"
	) as Dictionary
	var active_tail_layers: Array = descriptor.get(
		"active_tail_layers",
		[]
	) as Array
	var redo_tail_layers: Array = descriptor.get(
		"redo_tail_layers",
		[]
	) as Array
	var checkpoint_packet: Dictionary = descriptor.get(
		"checkpoint_packet",
		{}
	) as Dictionary
	return {
		"available": true,
		"bounded_history_enabled": bool(descriptor.get(
			"bounded_history_enabled",
			false
		)),
		"suspended_reason": String(descriptor.get(
			"suspended_reason",
			StringName()
		)),
		"recovery_blocked": bool(descriptor.get(
			"recovery_blocked",
			false
		)),
		"recovery_blocked_reason": String(descriptor.get(
			"recovery_blocked_reason",
			StringName()
		)),
		"pending_native_ack": bool(descriptor.get(
			"pending_native_ack",
			false
		)),
		"checkpoint_operation_count": int(descriptor.get(
			"checkpoint_operation_count",
			0
		)),
		"active_tail_layer_count": active_tail_layers.size(),
		"redo_tail_layer_count": redo_tail_layers.size(),
		"protected_layer_count": int(descriptor.get(
			"protected_layer_count",
			0
		)),
		"protected_body_count": int(descriptor.get(
			"protected_body_count",
			0
		)),
		"logical_body_count": int(descriptor.get(
			"logical_body_count",
			0
		)),
		"checkpoint_mesh_dirty": bool(checkpoint_packet.get(
			"checkpoint_mesh_dirty",
			false
		)),
		"materialized_mesh_operation_count": int(
			checkpoint_packet.get(
				"materialized_mesh_operation_count",
				0
			)
		),
		"checkpoint_cell_count": (
			(checkpoint_packet.get(
				"checkpoint_cell_materials",
				{}
			) as Dictionary).size()
		),
		"retained_authoring_body_count": (
			(authoring_state.get("material_bodies") as Array).size()
		),
		"retained_authoring_layer_count": (
			(authoring_state.get("forge_layers") as Array).size()
		),
	}


func _validate_bounded_stroke_invariants(
	row: Dictionary,
	stroke_number: int
) -> Dictionary:
	var failures: Array[String] = []
	var expected_checkpoint := maxi(
		stroke_number - BOUNDED_TAIL_CAPACITY,
		0
	)
	var expected_tail := mini(stroke_number, BOUNDED_TAIL_CAPACITY)
	var expected_protected := 1 if include_protected_handle else 0
	var expected_logical := (
		(1 if expected_checkpoint > 0 else 0)
		+ expected_tail
		+ expected_protected
	)
	var bounded_diagnostics := row.get(
		"bounded_history_diagnostics",
		{}
	) as Dictionary
	if not bool(row.get("bounded_history_enabled", false)):
		failures.append("bounded_history_disabled")
	if int(row.get("bounded_checkpoint_operation_count", -1)) != expected_checkpoint:
		failures.append("checkpoint_count_mismatch")
	if int(row.get("bounded_active_tail_layer_count", -1)) != expected_tail:
		failures.append("tail_count_mismatch")
	if (
		int(row.get("bounded_protected_body_count", -1))
		!= expected_protected
	):
		failures.append("protected_handle_count_mismatch")
	if (
		int(row.get("bounded_logical_body_count", -1)) != expected_logical
		or expected_logical > BOUNDED_LOGICAL_BODY_LIMIT
	):
		failures.append("logical_body_count_mismatch")
	if int(bounded_diagnostics.get(
		"retained_authoring_body_count",
		-1
	)) != expected_tail + expected_protected:
		failures.append("authoring_body_storage_unbounded")
	if int(bounded_diagnostics.get(
		"retained_authoring_layer_count",
		-1
	)) != expected_tail:
		failures.append("authoring_layer_storage_unbounded")
	var native_retained := int(row.get("native_retained_state_count", -1))
	if native_retained < 1 or native_retained > BOUNDED_NATIVE_STATE_LIMIT:
		failures.append("native_retained_state_count_unbounded")
	if int(row.get("native_prefix_body_count", -1)) > BOUNDED_TAIL_CAPACITY:
		failures.append("native_prefix_body_snapshot_unbounded")
	if bool(row.get("bounded_pending_native_ack", true)):
		failures.append("native_ack_still_pending")
	if bool(row.get("bounded_recovery_blocked", true)):
		failures.append("bounded_recovery_blocked")
	if int(row.get("native_fallback_count", -1)) != 0:
		failures.append("native_lane_fell_back")
	if int(row.get(
		"native_checkpoint_materialization_attempt_count",
		-1
	)) != 0:
		failures.append("hot_checkpoint_materialization_attempted")
	if int(row.get("native_checkpoint_materialization_count", -1)) != 0:
		failures.append("hot_checkpoint_materialized")
	return {
		"ok": failures.is_empty(),
		"failures": failures,
		"expected_checkpoint_operation_count": expected_checkpoint,
		"expected_tail_layer_count": expected_tail,
		"expected_protected_body_count": expected_protected,
		"expected_logical_body_count": expected_logical,
	}


func _build_fixture_bodies(count: int) -> Array[Resource]:
	var bodies: Array[Resource] = []
	for index in range(count):
		var body := (
			ForgeV2WorkpieceStressFixtureScript.build_seed_body()
			if index == 0
			else ForgeV2WorkpieceStressFixtureScript.build_operation_body(index - 1)
		)
		if body != null:
			bodies.append(body)
	return bodies


func _failed_row(
	stroke_number: int,
	failure: String,
	stroke_started: int,
	release_started: int = 0
) -> Dictionary:
	var now := Time.get_ticks_usec()
	return {
		"stroke": stroke_number,
		"committed": false,
		"stable_target_ready": false,
		"failure": failure,
		"finish_call_ms": 0.0,
		"release_to_ready_ms": float(now - release_started) / 1000.0 if release_started > 0 else 0.0,
		"stroke_total_ms": float(now - stroke_started) / 1000.0,
		"stroke_total_us": now - stroke_started,
		"memory_static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
	}


func _build_summary(source_rows: Array[Dictionary]) -> Dictionary:
	var ready_values := _metric_values(source_rows, "release_to_ready_ms")
	var finish_values := _metric_values(source_rows, "finish_call_ms")
	var stroke_values := _metric_values(source_rows, "stroke_total_ms")
	var frame_gap_values := _metric_values(source_rows, "max_wait_frame_gap_ms")
	var max_ready_index := _maximum_metric_index(source_rows, "release_to_ready_ms")
	var completed_within_window := 0
	var current_probe_lane_count := 0
	var stable_anchor_lane_count := 0
	var current_probe_instantaneous_miss_count := 0
	for row: Dictionary in source_rows:
		if (
			bool(row.get("stable_target_ready", false))
			and int(row.get("stable_ready_usec", 0)) <= benchmark_deadline_usec
		):
			completed_within_window += 1
		match StringName(row.get("readiness_probe_lane", StringName())):
			READINESS_PROBE_LANE_CURRENT_STROKE:
				current_probe_lane_count += 1
			READINESS_PROBE_LANE_STABLE_SEED_ANCHOR:
				stable_anchor_lane_count += 1
		if (
			bool(row.get("stable_target_ready", false))
			and not bool(row.get(
				"current_probe_instantaneous_new_target_ready",
				false
			))
		):
			current_probe_instantaneous_miss_count += 1
	var strict_window_observed := measurement_finished_usec >= benchmark_deadline_usec
	var first_count := mini(10, source_rows.size())
	var last_start := maxi(source_rows.size() - 10, 0)
	var first_rows := source_rows.slice(0, first_count)
	var last_rows := source_rows.slice(last_start)
	var worst_window := _worst_rolling_window(source_rows, 10)
	return {
		"completed_strokes": source_rows.filter(func(row: Dictionary) -> bool: return bool(row.get("stable_target_ready", false))).size(),
		"completed_within_window": completed_within_window,
		"strict_window_observed": strict_window_observed,
		"spm_strict_window": (
			float(completed_within_window) * 60.0 / window_seconds
			if strict_window_observed
			else null
		),
		"spm_over_measured_strokes": _window_spm(source_rows),
		"first_10_spm": _window_spm(first_rows),
		"last_10_spm": _window_spm(last_rows),
		"first_10_release_max_ms": _maximum_metric(first_rows, "release_to_ready_ms"),
		"last_10_release_max_ms": _maximum_metric(last_rows, "release_to_ready_ms"),
		"release_to_ready_p50_ms": _nearest_rank(ready_values, 0.50),
		"release_to_ready_p95_ms": _nearest_rank(ready_values, 0.95),
		"release_to_ready_p99_ms": _nearest_rank(ready_values, 0.99),
		"release_to_ready_max_ms": _maximum(ready_values),
		"release_to_ready_max_stroke": max_ready_index + 1,
		"release_to_ready_max_row": source_rows[max_ready_index] if max_ready_index >= 0 else {},
		"release_jitter_p95_minus_p50_ms": _nearest_rank(ready_values, 0.95) - _nearest_rank(ready_values, 0.50),
		"release_jitter_max_minus_p50_ms": _maximum(ready_values) - _nearest_rank(ready_values, 0.50),
		"finish_call_p95_ms": _nearest_rank(finish_values, 0.95),
		"finish_call_max_ms": _maximum(finish_values),
		"stroke_total_p95_ms": _nearest_rank(stroke_values, 0.95),
		"stroke_total_max_ms": _maximum(stroke_values),
		"max_wait_frame_gap_p95_ms": _nearest_rank(frame_gap_values, 0.95),
		"max_wait_frame_gap_max_ms": _maximum(frame_gap_values),
		"pause_counts": {
			"over_50ms": _count_over(ready_values, 50.0),
			"over_100ms": _count_over(ready_values, 100.0),
			"over_250ms": _count_over(ready_values, 250.0),
			"over_500ms": _count_over(ready_values, 500.0),
			"over_1000ms": _count_over(ready_values, 1000.0),
		},
		"readiness_probe_lanes": {
			"current_stroke": current_probe_lane_count,
			"stable_seed_anchor": stable_anchor_lane_count,
			"current_probe_instantaneous_miss_count": (
				current_probe_instantaneous_miss_count
			),
		},
		"worst_rolling_10": worst_window,
		"bounded_history": _build_bounded_history_summary(source_rows),
		"first_rows": first_rows,
		"last_rows": last_rows,
		"head_three_complete_cycles": _cycle_breakdown_rows(
			source_rows.slice(1, mini(4, source_rows.size()))
		),
		"tail_three_complete_cycles": _cycle_breakdown_rows(
			source_rows.slice(
				maxi(source_rows.size() - 4, 0),
				maxi(source_rows.size() - 1, 0)
			)
		),
	}


func _build_bounded_history_summary(
	source_rows: Array[Dictionary]
) -> Dictionary:
	if source_rows.is_empty():
		return {}
	var final_row: Dictionary = source_rows[source_rows.size() - 1]
	return {
		"final_checkpoint_operation_count": int(final_row.get(
			"bounded_checkpoint_operation_count",
			0
		)),
		"final_active_tail_layer_count": int(final_row.get(
			"bounded_active_tail_layer_count",
			0
		)),
		"final_protected_body_count": int(final_row.get(
			"bounded_protected_body_count",
			0
		)),
		"final_logical_body_count": int(final_row.get(
			"bounded_logical_body_count",
			0
		)),
		"maximum_logical_body_count": int(_maximum_metric(
			source_rows,
			"bounded_logical_body_count"
		)),
		"maximum_native_retained_state_count": int(_maximum_metric(
			source_rows,
			"native_retained_state_count"
		)),
		"final_native_boolean_count": int(final_row.get(
			"native_boolean_count",
			0
		)),
		"final_native_export_count": int(final_row.get(
			"native_export_count",
			0
		)),
		"maximum_checkpoint_materialization_attempt_count": int(
			_maximum_metric(
				source_rows,
				"native_checkpoint_materialization_attempt_count"
			)
		),
		"maximum_checkpoint_materialization_count": int(_maximum_metric(
			source_rows,
			"native_checkpoint_materialization_count"
		)),
		"recovery_blocked_stroke_count": _count_truthy(
			source_rows,
			"bounded_recovery_blocked"
		),
		"pending_native_ack_stroke_count": _count_truthy(
			source_rows,
			"bounded_pending_native_ack"
		),
	}


func _cycle_breakdown_rows(source_rows: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row_variant: Variant in source_rows:
		var row := row_variant as Dictionary
		if not row.has("cycle_start_to_next_start_ms"):
			continue
		result.append({
			"stroke": int(row.get("stroke", 0)),
			"cycle_start_to_next_start_ms": float(
				row.get("cycle_start_to_next_start_ms", 0.0)
			),
			"drawing_input_to_release_ms": float(
				row.get("input_to_release_ms", 0.0)
			),
			"synchronous_finish_ms": float(row.get("finish_call_ms", 0.0)),
			"deferred_finish_to_ready_ms": float(
				row.get("post_finish_ready_ms", 0.0)
			),
			"ready_to_next_stroke_ms": float(
				row.get("ready_to_next_stroke_ms", 0.0)
			),
			"release_to_ready_ms": float(row.get("release_to_ready_ms", 0.0)),
		})
	return result


func _worst_rolling_window(source_rows: Array[Dictionary], width: int) -> Dictionary:
	if source_rows.is_empty():
		return {}
	var actual_width := mini(width, source_rows.size())
	var worst := {}
	var worst_max := -1.0
	for start in range(source_rows.size() - actual_width + 1):
		var window_rows := source_rows.slice(start, start + actual_width)
		var window_max := _maximum_metric(window_rows, "release_to_ready_ms")
		if window_max > worst_max:
			worst_max = window_max
			worst = {
				"start_stroke": start + 1,
				"end_stroke": start + actual_width,
				"release_max_ms": window_max,
				"release_p95_ms": _nearest_rank(_metric_values(window_rows, "release_to_ready_ms"), 0.95),
				"spm": _window_spm(window_rows),
			}
	return worst


func _window_spm(source_rows: Array) -> float:
	var total_ms := 0.0
	var completed := 0
	for row_variant: Variant in source_rows:
		var row := row_variant as Dictionary
		if bool(row.get("stable_target_ready", false)):
			completed += 1
		total_ms += float(row.get("stroke_total_ms", 0.0))
	return float(completed) * 60000.0 / total_ms if total_ms > 0.0 else 0.0


func _metric_values(source_rows: Array, key: String) -> Array[float]:
	var values: Array[float] = []
	for row_variant: Variant in source_rows:
		values.append(float((row_variant as Dictionary).get(key, 0.0)))
	return values


func _nearest_rank(values: Array[float], percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var rank := clampi(int(ceil(percentile * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return sorted[rank]


func _maximum(values: Array[float]) -> float:
	var result := 0.0
	for value: float in values:
		result = maxf(result, value)
	return result


func _maximum_metric(source_rows: Array, key: String) -> float:
	return _maximum(_metric_values(source_rows, key))


func _maximum_metric_index(source_rows: Array, key: String) -> int:
	var result := -1
	var maximum := -INF
	for index in range(source_rows.size()):
		var value := float((source_rows[index] as Dictionary).get(key, 0.0))
		if value > maximum:
			maximum = value
			result = index
	return result


func _count_over(values: Array[float], threshold: float) -> int:
	var count := 0
	for value: float in values:
		if value > threshold:
			count += 1
	return count


func _count_truthy(source_rows: Array[Dictionary], key: String) -> int:
	var count := 0
	for row: Dictionary in source_rows:
		if bool(row.get(key, false)):
			count += 1
	return count


func _write_outputs(report: Dictionary) -> void:
	var json_text := JSON.stringify(report, "\t")
	_write_text(result_prefix + ".json", json_text + "\n")
	_write_text(LATEST_RESULT_PATH, json_text + "\n")
	var csv_text := _build_csv(rows)
	_write_text(result_prefix + ".csv", csv_text)
	_write_text(LATEST_CSV_PATH, csv_text)
	print(
		"FORGE_V2_LIVE_SPM_RESULT %s"
		% JSON.stringify({
			"path": result_prefix + ".json",
			"outcome": report.get("outcome", ""),
			"stop_reason": stop_reason,
			"summary": report.get("summary", {}),
		})
	)


func _build_csv(source_rows: Array[Dictionary]) -> String:
	var columns := PackedStringArray([
		"stroke", "committed", "stable_target_ready", "failure",
		"stroke_started_offset_ms", "release_started_offset_ms",
		"finish_return_offset_ms", "first_new_target_offset_ms", "stable_ready_offset_ms",
		"input_to_release_ms", "finish_to_first_target_ms", "first_target_to_stable_ms",
		"finish_call_ms", "first_new_target_ms", "release_to_ready_ms",
		"post_finish_ready_ms", "stroke_total_ms", "frames_to_ready",
		"ready_to_next_stroke_ms", "cycle_start_to_next_start_ms",
		"max_wait_frame_gap_ms", "target_before", "target_after",
		"target_changed", "readiness_probe_lane",
		"current_probe_instantaneous_new_target_ready",
		"current_probe_instantaneous_target_id", "memory_static_bytes",
		"bounded_checkpoint_operation_count",
		"bounded_active_tail_layer_count", "bounded_protected_body_count",
		"bounded_logical_body_count", "bounded_checkpoint_mesh_dirty",
		"bounded_history_enabled", "bounded_recovery_blocked",
		"bounded_pending_native_ack",
		"native_retained_state_count", "native_boolean_count",
		"native_export_count", "native_fallback_count",
		"native_prefix_body_count",
		"native_checkpoint_materialization_attempt_count",
		"native_checkpoint_materialization_count",
	])
	var lines := PackedStringArray([",".join(columns)])
	for row: Dictionary in source_rows:
		var fields := PackedStringArray()
		for column: String in columns:
			fields.append(_csv_escape(row.get(column, "")))
		lines.append(",".join(fields))
	return "\n".join(lines) + "\n"


func _csv_escape(value: Variant) -> String:
	var text := str(value)
	if text.contains(",") or text.contains("\"") or text.contains("\n"):
		return "\"%s\"" % text.replace("\"", "\"\"")
	return text


func _write_heartbeat(message: String) -> void:
	print("FORGE_V2_LIVE_SPM_HEARTBEAT " + message)
	_write_text(LATEST_HEARTBEAT_PATH, message + "\n")


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("could not write %s" % path)
		return
	file.store_string(content)
	file.flush()


func _build_run_id() -> String:
	return "%s_pid%d" % [
		Time.get_datetime_string_from_system(false, true).replace(":", "").replace("-", "").replace("T", "_").replace(" ", "_"),
		OS.get_process_id(),
	]


func _read_bool_environment(name: String, fallback: bool) -> bool:
	var raw := OS.get_environment(name).strip_edges().to_lower()
	if raw.is_empty():
		return fallback
	return raw in ["1", "true", "yes", "on"]


func _read_int_environment(name: String, fallback: int, minimum: int, maximum: int) -> int:
	var raw := OS.get_environment(name).strip_edges()
	return clampi(int(raw), minimum, maximum) if raw.is_valid_int() else fallback


func _read_float_environment(name: String, fallback: float, minimum: float, maximum: float) -> float:
	var raw := OS.get_environment(name).strip_edges()
	return clampf(float(raw), minimum, maximum) if raw.is_valid_float() else fallback


func _fail(message: String) -> void:
	if not errors.has(message):
		errors.append(message)
	push_error(message)
