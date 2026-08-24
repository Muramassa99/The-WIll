extends SceneTree

const FixtureScript = preload(
	"res://tools/forge_v2_workpiece_benchmark_fixture.gd"
)
const MeshAnalyzerScript = preload(
	"res://tools/forge_v2_workpiece_benchmark_mesh_analyzer.gd"
)
const RollingBackendScript = preload(
	"res://tools/forge_v2_rolling_csg_workpiece_backend.gd"
)
const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)
const ForgeV2VolumeStrokeScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_stroke.gd"
)

const VERIFIER_SCHEMA_VERSION := 1
const ABSORPTION_WINDOW_SIZE := 5
const SETTLE_FRAME_COUNT := 3
const VALID_OPERATION_COUNT := 5
const RESULT_BASE_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_rolling_csg_workpiece_backend"
)
const RESULT_JSON_PATH := RESULT_BASE_PATH + ".json"
const RESULT_TEXT_PATH := RESULT_BASE_PATH + ".txt"

var checks: Array[Dictionary] = []
var rejection_results: Array[Dictionary] = []
var errors: Array[String] = []
var peak_compile_operand_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_BASE_PATH.get_base_dir())
	var presenter: Node3D = ForgeV2VolumePreviewPresenterScript.new()
	presenter.name = "RollingBackendVerifierPresenter"
	root.add_child(presenter)
	var backend_host := Node3D.new()
	backend_host.name = "RollingBackendVerifierHost"
	root.add_child(backend_host)
	await process_frame

	var backend = RollingBackendScript.new()
	var initialize_result: Dictionary = backend.initialize(
		backend_host,
		presenter,
		ABSORPTION_WINDOW_SIZE
	)
	_record_check(
		"backend initializes with window 5",
		bool(initialize_result.get("ok", false))
		and int(initialize_result.get("absorption_window_size", 0))
		== ABSORPTION_WINDOW_SIZE,
		initialize_result
	)
	if not bool(initialize_result.get("ok", false)):
		await _finish(backend, backend_host, presenter)
		return

	var bodies: Array[Resource] = FixtureScript.build_body_sequence(
		VALID_OPERATION_COUNT
	)
	var seed_result: Dictionary = backend.initialize_seed(bodies[0])
	var seed_state := _capture_backend_state(backend)
	_record_check(
		"direct seed publishes revision zero",
		bool(seed_result.get("ok", false))
		and int(seed_state.get("accepted_revision", -1)) == 0
		and int(seed_state.get("accepted_base_revision", -1)) == 0
		and int(seed_state.get("pending_body_count", -1)) == 0
		and int(seed_state.get("accepted_source_body_count", -1)) == 1
		and int(seed_state.get("accepted_surface_count", 0)) == 1
		and not String(seed_state.get(
			"geometry_signature_oriented",
			""
		)).is_empty(),
		{
			"seed_result": seed_result,
			"state": seed_state,
		}
	)
	_record_check(
		"direct seed leaves no live CSG",
		_count_csg_nodes(backend_host) == 0
		and int(seed_result.get("steady_csg_shape_count", -1)) == 0
		and int(seed_result.get("steady_csg_operand_count", -1)) == 0,
		{
			"host_csg_shape_count": _count_csg_nodes(backend_host),
			"seed_result": seed_result,
		}
	)
	if not bool(seed_result.get("ok", false)):
		await _finish(backend, backend_host, presenter)
		return

	var first_add_result: Dictionary = await backend.apply_add_body(
		bodies[1],
		SETTLE_FRAME_COUNT,
		false
	)
	_record_valid_add_check(backend, first_add_result, 1)

	var void_body := _duplicate_with_changes(bodies[2], {
		"operation_mode": ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL,
	})
	await _verify_rejected_command(
		backend,
		void_body,
		"unsupported VOID command is atomic",
		"rolling_backend_v1_operation_unsupported"
	)

	var empty_only_body := _duplicate_with_changes(bodies[2], {
		"placement_policy": ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY,
	})
	await _verify_rejected_command(
		backend,
		empty_only_body,
		"unsupported Empty Only command is atomic",
		"rolling_backend_v1_placement_policy_unsupported"
	)

	var handle_body := _duplicate_with_changes(bodies[2], {
		"body_kind": ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE,
	})
	await _verify_rejected_command(
		backend,
		handle_body,
		"unsupported Handle command is atomic",
		"rolling_backend_v1_body_kind_unsupported"
	)

	var second_material_body := _duplicate_with_changes(bodies[2], {
		"material_variant_id": &"mat_steel",
	})
	await _verify_rejected_command(
		backend,
		second_material_body,
		"unsupported second-material command is atomic",
		"rolling_backend_v1_multiple_materials_unsupported"
	)

	for operation_index in range(2, VALID_OPERATION_COUNT + 1):
		var add_result: Dictionary = await backend.apply_add_body(
			bodies[operation_index],
			SETTLE_FRAME_COUNT,
			false
		)
		_record_valid_add_check(backend, add_result, operation_index)

	var final_state := _capture_backend_state(backend)
	var final_host_csg_count := _count_csg_nodes(backend_host)
	_record_check(
		"window 5 bounds peak operands and absorbs five accepted commands",
		peak_compile_operand_count == ABSORPTION_WINDOW_SIZE + 1
		and int(final_state.get("accepted_revision", -1))
		== VALID_OPERATION_COUNT
		and int(final_state.get("accepted_base_revision", -1))
		== VALID_OPERATION_COUNT
		and int(final_state.get("pending_body_count", -1)) == 0,
		{
			"peak_compile_operand_count": peak_compile_operand_count,
			"allowed_peak_compile_operand_count": (
				ABSORPTION_WINDOW_SIZE + 1
			),
			"state": final_state,
		}
	)
	_record_check(
		"accepted steady state contains one mesh and zero CSG",
		final_host_csg_count == 0
		and _count_mesh_instances(backend_host) == 1
		and int(final_state.get("accepted_surface_count", 0)) == 1,
		{
			"host_csg_shape_count": final_host_csg_count,
			"host_mesh_instance_count": _count_mesh_instances(backend_host),
			"accepted_surface_count": int(final_state.get(
				"accepted_surface_count",
				0
			)),
		}
	)

	await _finish(backend, backend_host, presenter)


func _record_valid_add_check(
	backend: Variant,
	result: Dictionary,
	expected_revision: int
) -> void:
	var expected_pending := expected_revision % ABSORPTION_WINDOW_SIZE
	var expected_base_revision := (
		expected_revision - expected_pending
	)
	var expected_compile_operands := expected_pending + 1
	if expected_pending == 0:
		expected_compile_operands = ABSORPTION_WINDOW_SIZE + 1
	peak_compile_operand_count = maxi(
		peak_compile_operand_count,
		int(result.get("compile_csg_operand_count", 0))
	)
	var state := _capture_backend_state(backend)
	_record_check(
		"valid Add accepts revision %d" % expected_revision,
		bool(result.get("ok", false))
		and int(state.get("accepted_revision", -1)) == expected_revision
		and int(state.get("accepted_source_body_count", -1))
		== expected_revision + 1
		and int(state.get("accepted_base_revision", -1))
		== expected_base_revision
		and int(state.get("pending_body_count", -1)) == expected_pending
		and int(result.get("compile_csg_operand_count", -1))
		== expected_compile_operands
		and int(result.get("steady_csg_shape_count", -1)) == 0
		and int(result.get("steady_csg_operand_count", -1)) == 0
		and _count_csg_nodes(backend.get("host_node") as Node) == 0,
		{
			"result": result,
			"state": state,
			"expected_compile_operand_count": expected_compile_operands,
		}
	)


func _verify_rejected_command(
	backend: Variant,
	body: Resource,
	label: String,
	expected_error: String
) -> void:
	var before := _capture_backend_state(backend)
	var result: Dictionary = await backend.apply_add_body(
		body,
		SETTLE_FRAME_COUNT,
		false
	)
	var after := _capture_backend_state(backend)
	var unchanged := before == after
	var passed := (
		not bool(result.get("ok", false))
		and String(result.get("error", "")) == expected_error
		and unchanged
		and _count_csg_nodes(backend.get("host_node") as Node) == 0
	)
	var record := {
		"label": label,
		"passed": passed,
		"expected_error": expected_error,
		"actual_result": result,
		"state_unchanged": unchanged,
		"before": before,
		"after": after,
	}
	rejection_results.append(record)
	_record_check(label, passed, record)


func _capture_backend_state(backend: Variant) -> Dictionary:
	var mesh: ArrayMesh = backend.call("get_accepted_mesh") as ArrayMesh
	var analysis: Dictionary = MeshAnalyzerScript.analyze_mesh(mesh)
	var base_mesh: ArrayMesh = backend.get("accepted_base_mesh") as ArrayMesh
	var pending: Array = backend.get("pending_bodies") as Array
	return {
		"accepted_revision": int(backend.call("get_accepted_revision")),
		"accepted_base_revision": int(backend.get("accepted_base_revision")),
		"pending_body_count": pending.size(),
		"accepted_source_body_count": int(backend.get(
			"accepted_source_body_count"
		)),
		"accepted_material_variant_id": String(backend.get(
			"accepted_material_variant_id"
		)),
		"accepted_mesh_instance_id": (
			mesh.get_instance_id() if mesh != null else 0
		),
		"accepted_base_mesh_instance_id": (
			base_mesh.get_instance_id() if base_mesh != null else 0
		),
		"accepted_surface_count": (
			mesh.get_surface_count() if mesh != null else 0
		),
		"triangle_count": int(analysis.get("triangle_count", 0)),
		"geometry_signature_oriented": String(analysis.get(
			"geometry_signature_oriented",
			""
		)),
		"geometry_signature_unoriented": String(analysis.get(
			"geometry_signature_unoriented",
			""
		)),
	}


func _duplicate_with_changes(
	source: Resource,
	changes: Dictionary
) -> Resource:
	var result := source.duplicate(true) as Resource
	for property_name: Variant in changes.keys():
		result.set(StringName(property_name), changes[property_name])
	return result


func _record_check(
	label: String,
	passed: bool,
	details: Dictionary
) -> void:
	checks.append({
		"label": label,
		"passed": passed,
		"details": details,
	})
	if passed:
		print("PASS: %s" % label)
	else:
		var message := "FAIL: %s" % label
		errors.append(message)
		push_error(message)


func _finish(
	backend: Variant,
	backend_host: Node3D,
	presenter: Node3D
) -> void:
	var ok := errors.is_empty()
	var payload := {
		"verifier_schema": VERIFIER_SCHEMA_VERSION,
		"ok": ok,
		"backend_id": String(RollingBackendScript.BACKEND_ID),
		"backend_schema": RollingBackendScript.BACKEND_SCHEMA_VERSION,
		"fixture_id": String(FixtureScript.FIXTURE_ID),
		"fixture_signature": FixtureScript.build_fixture_signature(
			VALID_OPERATION_COUNT
		),
		"absorption_window_size": ABSORPTION_WINDOW_SIZE,
		"valid_operation_count": VALID_OPERATION_COUNT,
		"peak_compile_operand_count": peak_compile_operand_count,
		"engine_version": Engine.get_version_info(),
		"checks": checks,
		"rejection_results": rejection_results,
		"errors": errors,
	}
	_write_json(RESULT_JSON_PATH, payload)
	_write_text(RESULT_TEXT_PATH, payload)
	if backend != null:
		backend.call("dispose")
	if backend_host != null and is_instance_valid(backend_host):
		if backend_host.get_parent() != null:
			backend_host.get_parent().remove_child(backend_host)
		backend_host.free()
	if presenter != null and is_instance_valid(presenter):
		if presenter.get_parent() != null:
			presenter.get_parent().remove_child(presenter)
		presenter.free()
	print(
		"Forge V2 rolling backend verifier: %s (%s)"
		% ["PASS" if ok else "FAIL", RESULT_TEXT_PATH]
	)
	quit(0 if ok else 1)


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write verifier JSON: %s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t", false))
	file.store_string("\n")
	file.close()


func _write_text(path: String, payload: Dictionary) -> void:
	var lines := PackedStringArray([
		"Forge V2 Rolling CSG Workpiece Backend Verifier",
		"Result: %s" % ("PASS" if bool(payload.get("ok", false)) else "FAIL"),
		"Backend: %s schema %d" % [
			String(payload.get("backend_id", "")),
			int(payload.get("backend_schema", 0)),
		],
		"Fixture: %s" % String(payload.get("fixture_id", "")),
		"Fixture signature: %s" % String(payload.get(
			"fixture_signature",
			""
		)),
		"Absorption window: %d" % ABSORPTION_WINDOW_SIZE,
		"Accepted Add commands: %d" % VALID_OPERATION_COUNT,
		"Peak compile operands: %d (limit %d)" % [
			peak_compile_operand_count,
			ABSORPTION_WINDOW_SIZE + 1,
		],
		"",
		"Checks:",
	])
	for check: Dictionary in checks:
		lines.append(
			"- %s: %s"
			% [
				"PASS" if bool(check.get("passed", false)) else "FAIL",
				String(check.get("label", "")),
			]
		)
	if not errors.is_empty():
		lines.append("")
		lines.append("Errors:")
		for error: String in errors:
			lines.append("- %s" % error)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write verifier text: %s" % path)
		return
	file.store_string("\n".join(lines))
	file.store_string("\n")
	file.close()


func _count_csg_nodes(node: Node) -> int:
	if node == null:
		return -1
	var count := 1 if node is CSGShape3D else 0
	for child: Node in node.get_children():
		count += _count_csg_nodes(child)
	return count


func _count_mesh_instances(node: Node) -> int:
	if node == null:
		return -1
	var count := 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children():
		count += _count_mesh_instances(child)
	return count
