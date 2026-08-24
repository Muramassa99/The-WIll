extends SceneTree

const FixtureScript = preload(
	"res://tools/forge_v2_workpiece_benchmark_fixture.gd"
)
const MeshAnalyzerScript = preload(
	"res://tools/forge_v2_workpiece_benchmark_mesh_analyzer.gd"
)
const ForgeV2VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)

const VERIFIER_SCHEMA_VERSION := 1
const SETTLE_FRAME_COUNT := 3
const TOTAL_REFEED_CYCLES := 100
const CHECKPOINTS := [1, 10, 25, 50, 100]
const RESULT_BASE_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_rolling_csg_noop_refeed"
)
const RESULT_JSON_PATH := RESULT_BASE_PATH + ".json"
const RESULT_TEXT_PATH := RESULT_BASE_PATH + ".txt"

var checkpoint_rows: Array[Dictionary] = []
var errors: Array[String] = []
var completed_cycle_count := 0
var maximum_frame_gap_ms := 0.0
var maximum_refeed_wall_ms := 0.0
var peak_transient_csg_shape_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_BASE_PATH.get_base_dir())
	var presenter: Node3D = ForgeV2VolumePreviewPresenterScript.new()
	presenter.name = "NoOpRefeedPresenter"
	root.add_child(presenter)
	var host := Node3D.new()
	host.name = "NoOpRefeedHost"
	root.add_child(host)
	await process_frame

	var bodies: Array[Resource] = FixtureScript.build_body_sequence(0)
	if bodies.size() != 1 or bodies[0] == null:
		errors.append("deterministic_seed_body_missing")
		await _finish(null, {}, {}, host, presenter)
		return
	var accepted_mesh := presenter.call(
		"_build_active_material_body_sweep_mesh",
		bodies[0]
	) as ArrayMesh
	if accepted_mesh == null or accepted_mesh.get_surface_count() <= 0:
		errors.append("deterministic_seed_sweep_mesh_missing")
		await _finish(null, {}, {}, host, presenter)
		return

	var initial_analysis: Dictionary = MeshAnalyzerScript.analyze_mesh(
		accepted_mesh
	)
	var initial_exact_signature := _exact_mesh_array_signature(accepted_mesh)
	var initial_health_errors := _mesh_health_errors(initial_analysis)
	for health_error: String in initial_health_errors:
		errors.append("initial_seed:%s" % health_error)

	for cycle_index in range(1, TOTAL_REFEED_CYCLES + 1):
		var refeed_result: Dictionary = await _refeed_once(
			host,
			accepted_mesh
		)
		if not bool(refeed_result.get("ok", false)):
			errors.append(
				"cycle_%d:%s"
				% [
					cycle_index,
					String(refeed_result.get("error", "refeed_failed")),
				]
			)
			break
		accepted_mesh = refeed_result.get("mesh") as ArrayMesh
		completed_cycle_count = cycle_index
		maximum_frame_gap_ms = maxf(
			maximum_frame_gap_ms,
			float(refeed_result.get("max_frame_gap_ms", 0.0))
		)
		maximum_refeed_wall_ms = maxf(
			maximum_refeed_wall_ms,
			float(refeed_result.get("refeed_wall_ms", 0.0))
		)
		peak_transient_csg_shape_count = maxi(
			peak_transient_csg_shape_count,
			int(refeed_result.get("transient_csg_shape_count", 0))
		)
		var analysis: Dictionary = MeshAnalyzerScript.analyze_mesh(
			accepted_mesh
		)
		var health_errors := _mesh_health_errors(analysis)
		for health_error: String in health_errors:
			errors.append("cycle_%d:%s" % [cycle_index, health_error])
		var steady_csg_shape_count := _count_csg_shapes(host)
		if steady_csg_shape_count != 0:
			errors.append(
				"cycle_%d:steady_csg_shape_count_%d"
				% [cycle_index, steady_csg_shape_count]
			)
		if CHECKPOINTS.has(cycle_index):
			var surface_comparison: Dictionary = (
				MeshAnalyzerScript.compare_surfaces(
					initial_analysis,
					analysis
				)
			)
			var exact_signature := _exact_mesh_array_signature(
				accepted_mesh
			)
			var row := _build_checkpoint_row(
				cycle_index,
				initial_analysis,
				analysis,
				surface_comparison,
				initial_exact_signature,
				exact_signature,
				health_errors,
				refeed_result,
				steady_csg_shape_count
			)
			checkpoint_rows.append(row)
			_print_checkpoint(row)

	await _finish(
		accepted_mesh,
		initial_analysis,
		{
			"exact_mesh_array_signature": initial_exact_signature,
		},
		host,
		presenter
	)


func _refeed_once(host: Node3D, accepted_mesh: ArrayMesh) -> Dictionary:
	if host == null or accepted_mesh == null:
		return {
			"ok": false,
			"error": "refeed_input_missing",
		}
	var refeed_started := Time.get_ticks_usec()
	var staging_root := CSGCombiner3D.new()
	staging_root.name = "NoOpRefeedStaging"
	staging_root.operation = CSGShape3D.OPERATION_UNION
	staging_root.calculate_tangents = false
	staging_root.use_collision = false
	host.add_child(staging_root)
	var accepted_operand := CSGMesh3D.new()
	accepted_operand.name = "AcceptedMeshOnlyOperand"
	accepted_operand.operation = CSGShape3D.OPERATION_UNION
	accepted_operand.calculate_tangents = false
	accepted_operand.mesh = accepted_mesh
	staging_root.add_child(accepted_operand)
	var transient_csg_shape_count := _count_csg_shapes(staging_root)
	var frame_gaps_ms: Array[float] = []
	for _frame_index in range(SETTLE_FRAME_COUNT):
		var frame_started := Time.get_ticks_usec()
		await process_frame
		frame_gaps_ms.append(_elapsed_milliseconds(frame_started))
	var bake_started := Time.get_ticks_usec()
	var baked_mesh := staging_root.bake_static_mesh()
	var bake_ms := _elapsed_milliseconds(bake_started)
	_discard_staging_root(staging_root)
	if baked_mesh == null or baked_mesh.get_surface_count() <= 0:
		return {
			"ok": false,
			"error": "refeed_bake_empty",
			"transient_csg_shape_count": transient_csg_shape_count,
			"bake_ms": bake_ms,
		}
	return {
		"ok": true,
		"mesh": baked_mesh,
		"transient_csg_shape_count": transient_csg_shape_count,
		"max_frame_gap_ms": _maximum_float(frame_gaps_ms),
		"bake_ms": bake_ms,
		"refeed_wall_ms": _elapsed_milliseconds(refeed_started),
	}


func _mesh_health_errors(analysis: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if int(analysis.get("triangle_count", 0)) <= 0:
		result.append("authoring_triangle_count_not_positive")
	if int(analysis.get("nonfinite_vertex_count", 0)) != 0:
		result.append("nonfinite_vertices")
	if int(analysis.get("degenerate_triangle_count", 0)) != 0:
		result.append("degenerate_triangles")
	if not bool(analysis.get("watertight", false)):
		result.append("authoring_not_watertight")
	if int(analysis.get("component_count", 0)) != 1:
		result.append("authoring_component_count_not_one")
	if int(analysis.get("boundary_edge_count", 0)) != 0:
		result.append("authoring_boundary_edges")
	if int(analysis.get("nonmanifold_edge_count", 0)) != 0:
		result.append("authoring_nonmanifold_edges")
	if int(analysis.get("directed_edge_mismatch_count", 0)) != 0:
		result.append("authoring_directed_edge_mismatch")
	if int(analysis.get("euler_characteristic", 0)) != 2:
		result.append("authoring_euler_not_two")
	if absf(float(analysis.get("genus", 0.0))) > 0.000001:
		result.append("authoring_genus_not_zero")
	if int(analysis.get("strict_triangle_count", 0)) <= 0:
		result.append("strict_triangle_count_not_positive")
	if int(analysis.get(
		"strict_degenerate_triangle_collapse_count",
		0
	)) != 0:
		result.append("strict_degenerate_triangle_collapse")
	if not bool(analysis.get("strict_watertight", false)):
		result.append("strict_not_watertight")
	if int(analysis.get("strict_component_count", 0)) != 1:
		result.append("strict_component_count_not_one")
	if int(analysis.get("strict_boundary_edge_count", 0)) != 0:
		result.append("strict_boundary_edges")
	if int(analysis.get("strict_nonmanifold_edge_count", 0)) != 0:
		result.append("strict_nonmanifold_edges")
	if int(analysis.get("strict_directed_edge_mismatch_count", 0)) != 0:
		result.append("strict_directed_edge_mismatch")
	if int(analysis.get("strict_euler_characteristic", 0)) != 2:
		result.append("strict_euler_not_two")
	if absf(float(analysis.get("strict_genus", 0.0))) > 0.000001:
		result.append("strict_genus_not_zero")
	return result


func _build_checkpoint_row(
	cycle_index: int,
	initial: Dictionary,
	current: Dictionary,
	surface_comparison: Dictionary,
	initial_exact_signature: String,
	current_exact_signature: String,
	health_errors: Array[String],
	refeed_result: Dictionary,
	steady_csg_shape_count: int
) -> Dictionary:
	var initial_volume := float(initial.get(
		"absolute_volume_cubic_meters",
		0.0
	))
	var current_volume := float(current.get(
		"absolute_volume_cubic_meters",
		0.0
	))
	var absolute_volume_delta := absf(current_volume - initial_volume)
	var relative_volume_delta := (
		absolute_volume_delta / initial_volume
		if initial_volume > 0.0
		else INF
	)
	var authoring_oriented_signature := String(current.get(
		"geometry_signature_oriented",
		""
	))
	var authoring_unoriented_signature := String(current.get(
		"geometry_signature_unoriented",
		""
	))
	return {
		"cycle": cycle_index,
		"topology_gate_passed": health_errors.is_empty(),
		"health_errors": health_errors,
		"surface_count": int(current.get("surface_count", 0)),
		"triangle_count": int(current.get("triangle_count", 0)),
		"strict_triangle_count": int(current.get(
			"strict_triangle_count",
			0
		)),
		"exact_mesh_array_signature": current_exact_signature,
		"exact_mesh_array_signature_matches_initial": (
			current_exact_signature == initial_exact_signature
		),
		"geometry_signature_oriented": authoring_oriented_signature,
		"geometry_signature_oriented_matches_initial": (
			authoring_oriented_signature
			== String(initial.get("geometry_signature_oriented", ""))
		),
		"geometry_signature_unoriented": authoring_unoriented_signature,
		"geometry_signature_unoriented_matches_initial": (
			authoring_unoriented_signature
			== String(initial.get("geometry_signature_unoriented", ""))
		),
		"aabb_position_max_delta_meters": _maximum_field_delta(
			initial,
			current,
			[
				"aabb_position_x",
				"aabb_position_y",
				"aabb_position_z",
			]
		),
		"aabb_size_max_delta_meters": _maximum_field_delta(
			initial,
			current,
			[
				"aabb_size_x",
				"aabb_size_y",
				"aabb_size_z",
			]
		),
		"absolute_volume_cubic_meters": current_volume,
		"absolute_volume_delta_cubic_meters": absolute_volume_delta,
		"relative_volume_delta": relative_volume_delta,
		"signed_volume_sign": float(current.get("signed_volume_sign", 0.0)),
		"signed_volume_sign_matches_initial": (
			float(current.get("signed_volume_sign", 0.0))
			== float(initial.get("signed_volume_sign", 0.0))
		),
		"surface_first_to_current_max_meters": float(
			surface_comparison.get("first_to_second_max_meters", INF)
		),
		"surface_current_to_first_max_meters": float(
			surface_comparison.get("second_to_first_max_meters", INF)
		),
		"surface_bidirectional_max_meters": float(
			surface_comparison.get("bidirectional_max_meters", INF)
		),
		"authoring_watertight": bool(current.get("watertight", false)),
		"authoring_component_count": int(current.get(
			"component_count",
			0
		)),
		"authoring_boundary_edge_count": int(current.get(
			"boundary_edge_count",
			0
		)),
		"authoring_nonmanifold_edge_count": int(current.get(
			"nonmanifold_edge_count",
			0
		)),
		"strict_watertight": bool(current.get(
			"strict_watertight",
			false
		)),
		"strict_component_count": int(current.get(
			"strict_component_count",
			0
		)),
		"strict_boundary_edge_count": int(current.get(
			"strict_boundary_edge_count",
			0
		)),
		"strict_nonmanifold_edge_count": int(current.get(
			"strict_nonmanifold_edge_count",
			0
		)),
		"refeed_wall_ms": float(refeed_result.get("refeed_wall_ms", 0.0)),
		"max_frame_gap_ms": float(refeed_result.get("max_frame_gap_ms", 0.0)),
		"bake_ms": float(refeed_result.get("bake_ms", 0.0)),
		"transient_csg_shape_count": int(refeed_result.get(
			"transient_csg_shape_count",
			0
		)),
		"steady_csg_shape_count": steady_csg_shape_count,
	}


func _finish(
	accepted_mesh: ArrayMesh,
	initial_analysis: Dictionary,
	initial_signatures: Dictionary,
	host: Node3D,
	presenter: Node3D
) -> void:
	var ok := (
		errors.is_empty()
		and completed_cycle_count == TOTAL_REFEED_CYCLES
		and checkpoint_rows.size() == CHECKPOINTS.size()
	)
	if completed_cycle_count != TOTAL_REFEED_CYCLES:
		errors.append(
			"completed_cycle_count_%d_expected_%d"
			% [completed_cycle_count, TOTAL_REFEED_CYCLES]
		)
	if checkpoint_rows.size() != CHECKPOINTS.size():
		errors.append(
			"checkpoint_count_%d_expected_%d"
			% [checkpoint_rows.size(), CHECKPOINTS.size()]
		)
	ok = errors.is_empty()
	var final_analysis := (
		MeshAnalyzerScript.analyze_mesh(accepted_mesh)
		if accepted_mesh != null
		else {}
	)
	var payload := {
		"verifier_schema": VERIFIER_SCHEMA_VERSION,
		"ok": ok,
		"fixture_id": String(FixtureScript.FIXTURE_ID),
		"fixture_signature": FixtureScript.build_fixture_signature(0),
		"fixture_source": "deterministic_in_memory_seed_only",
		"writes_live_wip_library": false,
		"protected_live_wips_accessed": false,
		"protected_live_wip_names": [
			"Test Glave",
			"Test sword for animations",
		],
		"settle_frame_count": SETTLE_FRAME_COUNT,
		"requested_refeed_cycles": TOTAL_REFEED_CYCLES,
		"completed_refeed_cycles": completed_cycle_count,
		"checkpoints": CHECKPOINTS,
		"peak_transient_csg_shape_count": peak_transient_csg_shape_count,
		"steady_csg_shape_count": _count_csg_shapes(host),
		"maximum_frame_gap_ms": maximum_frame_gap_ms,
		"maximum_refeed_wall_ms": maximum_refeed_wall_ms,
		"initial_exact_mesh_array_signature": String(
			initial_signatures.get("exact_mesh_array_signature", "")
		),
		"initial_analysis": MeshAnalyzerScript.strip_transient_arrays(
			initial_analysis
		),
		"final_analysis": MeshAnalyzerScript.strip_transient_arrays(
			final_analysis
		),
		"checkpoint_rows": checkpoint_rows,
		"engine_version": Engine.get_version_info(),
		"result_json_path": RESULT_JSON_PATH,
		"result_text_path": RESULT_TEXT_PATH,
		"errors": errors,
	}
	_write_json(RESULT_JSON_PATH, payload)
	_write_text(RESULT_TEXT_PATH, payload)
	if host != null and is_instance_valid(host):
		if host.get_parent() != null:
			host.get_parent().remove_child(host)
		host.free()
	if presenter != null and is_instance_valid(presenter):
		if presenter.get_parent() != null:
			presenter.get_parent().remove_child(presenter)
		presenter.free()
	print(
		"Forge V2 rolling CSG no-op refeed verifier: %s (%s)"
		% ["PASS" if ok else "FAIL", RESULT_TEXT_PATH]
	)
	quit(0 if ok else 1)


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write no-op refeed verifier JSON: %s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t", false))
	file.store_string("\n")
	file.close()


func _write_text(path: String, payload: Dictionary) -> void:
	var lines := PackedStringArray([
		"Forge V2 Rolling CSG No-op Refeed Verifier",
		"Result: %s" % ("PASS" if bool(payload.get("ok", false)) else "FAIL"),
		"Fixture: deterministic in-memory seed sweep only",
		"Live WIP library accessed: no",
		"Refeed: accepted ArrayMesh as sole CSGMesh operand",
		"Settle frames per cycle: %d" % SETTLE_FRAME_COUNT,
		"Completed cycles: %d/%d" % [
			completed_cycle_count,
			TOTAL_REFEED_CYCLES,
		],
		"Peak transient CSG shapes: %d" % peak_transient_csg_shape_count,
		"Steady CSG shapes: %d" % int(payload.get(
			"steady_csg_shape_count",
			-1
		)),
		"Maximum frame gap: %.3f ms" % maximum_frame_gap_ms,
		"Maximum refeed wall time: %.3f ms" % maximum_refeed_wall_ms,
		"",
		"Checkpoint results:",
	])
	for row: Dictionary in checkpoint_rows:
		lines.append(
			(
				"- cycle %d: topology=%s triangles=%d exact_arrays=%s "
				+ "oriented_signature=%s unoriented_signature=%s "
				+ "aabb_position_delta=%.12f m aabb_size_delta=%.12f m "
				+ "volume_delta=%.12f m^3 relative_volume_delta=%.12f "
				+ "surface_delta=%.12f m"
			)
			% [
				int(row.get("cycle", 0)),
				"PASS" if bool(row.get("topology_gate_passed", false)) else "FAIL",
				int(row.get("triangle_count", 0)),
				"same" if bool(row.get(
					"exact_mesh_array_signature_matches_initial",
					false
				)) else "changed",
				"same" if bool(row.get(
					"geometry_signature_oriented_matches_initial",
					false
				)) else "changed",
				"same" if bool(row.get(
					"geometry_signature_unoriented_matches_initial",
					false
				)) else "changed",
				float(row.get("aabb_position_max_delta_meters", 0.0)),
				float(row.get("aabb_size_max_delta_meters", 0.0)),
				float(row.get("absolute_volume_delta_cubic_meters", 0.0)),
				float(row.get("relative_volume_delta", 0.0)),
				float(row.get("surface_bidirectional_max_meters", 0.0)),
			]
		)
	if not errors.is_empty():
		lines.append("")
		lines.append("Errors:")
		for error: String in errors:
			lines.append("- %s" % error)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write no-op refeed verifier text: %s" % path)
		return
	file.store_string("\n".join(lines))
	file.store_string("\n")
	file.close()


func _print_checkpoint(row: Dictionary) -> void:
	print(
		(
			"NOOP_REFEED cycle=%d topology=%s triangles=%d "
			+ "exact_arrays=%s surface_delta_m=%.12f"
		)
		% [
			int(row.get("cycle", 0)),
			"PASS" if bool(row.get("topology_gate_passed", false)) else "FAIL",
			int(row.get("triangle_count", 0)),
			"same" if bool(row.get(
				"exact_mesh_array_signature_matches_initial",
				false
			)) else "changed",
			float(row.get("surface_bidirectional_max_meters", 0.0)),
		]
	)


func _exact_mesh_array_signature(mesh: ArrayMesh) -> String:
	if mesh == null:
		return ""
	var hashing_context := HashingContext.new()
	if hashing_context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	hashing_context.update(var_to_bytes(mesh.get_surface_count()))
	for surface_index in range(mesh.get_surface_count()):
		hashing_context.update(var_to_bytes(
			mesh.surface_get_primitive_type(surface_index)
		))
		hashing_context.update(var_to_bytes(
			mesh.surface_get_format(surface_index)
		))
		hashing_context.update(var_to_bytes(
			mesh.surface_get_arrays(surface_index)
		))
	return hashing_context.finish().hex_encode()


func _maximum_field_delta(
	first: Dictionary,
	second: Dictionary,
	field_names: Array[String]
) -> float:
	var result := 0.0
	for field_name: String in field_names:
		result = maxf(
			result,
			absf(float(first.get(field_name, 0.0)) - float(
				second.get(field_name, 0.0)
			))
		)
	return result


func _count_csg_shapes(node: Node) -> int:
	if node == null:
		return 0
	var count := 1 if node is CSGShape3D else 0
	for child: Node in node.get_children():
		count += _count_csg_shapes(child)
	return count


func _discard_staging_root(staging_root: Node) -> void:
	if staging_root == null or not is_instance_valid(staging_root):
		return
	if staging_root.get_parent() != null:
		staging_root.get_parent().remove_child(staging_root)
	staging_root.free()


func _elapsed_milliseconds(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


func _maximum_float(values: Array[float]) -> float:
	var result := 0.0
	for value: float in values:
		result = maxf(result, value)
	return result
