extends SceneTree

const MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const PresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)
const MeshAnalyzerScript = preload(
	"res://tools/forge_v2_workpiece_benchmark_mesh_analyzer.gd"
)

const MATERIAL_VARIANT_ID := &"mat_iron_gray"
const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "benchmark_forge_v2_capsule_csg_operand_readiness.json"
)
const RADIUS_METERS := 0.06
const READINESS_FRAME_PAIR_LIMIT := 4
const IMMEDIATE_BAKE_REPETITIONS := 24
const ONE_PROCESS_FRAME_REPETITIONS := 24


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var presenter := PresenterScript.new() as Node3D
	root.add_child(presenter)
	var cases := {
		"one_point": PackedVector3Array([
			Vector3(0.11, 0.03, -0.04),
		]),
		"straight": PackedVector3Array([
			Vector3.ZERO,
			Vector3(0.36, 0.0, 0.0),
		]),
		"right_angle": PackedVector3Array([
			Vector3.ZERO,
			Vector3(0.18, 0.0, 0.0),
			Vector3(0.18, 0.18, 0.0),
		]),
		"spatial_bend": PackedVector3Array([
			Vector3.ZERO,
			Vector3(0.14, 0.03, 0.02),
			Vector3(0.25, 0.12, -0.04),
			Vector3(0.34, 0.16, 0.05),
		]),
	}
	var results: Dictionary = {}
	var all_exact := true
	var all_ready_within_limit := true
	for case_id: String in cases.keys():
		var body := _build_body(StringName(case_id), cases[case_id])
		var oracle := await _build_delayed_oracle(
			presenter,
			body,
			case_id
		)
		_require(bool(oracle.get("ok", false)), "%s oracle failed" % case_id)
		var oracle_mesh := oracle.get("mesh", null) as ArrayMesh
		var oracle_analysis := MeshAnalyzerScript.analyze_mesh(oracle_mesh)
		var readiness := await _probe_readiness(
			presenter,
			body,
			case_id,
			oracle_analysis
		)
		var immediate := await _benchmark_immediate_bake(
			presenter,
			body,
			case_id,
			oracle_analysis
		)
		var one_process_frame := await _benchmark_one_process_frame_bake(
			presenter,
			body,
			case_id,
			oracle_analysis
		)
		var case_exact := (
			bool(readiness.get("exact_geometry", false))
			and bool(one_process_frame.get(
				"all_generated_packets_ready",
				false
			))
			and bool(one_process_frame.get(
				"representative_exact_geometry",
				false
			))
			and bool(one_process_frame.get(
				"native_backend_accepts_packet",
				false
			))
		)
		var ready_within_limit := bool(readiness.get(
			"ready_within_frame_pair_limit",
			false
		))
		all_exact = all_exact and case_exact
		all_ready_within_limit = (
			all_ready_within_limit and ready_within_limit
		)
		results[case_id] = {
			"path_point_count": body.path_points.size(),
			"oracle_wait": oracle.get("wait", {}),
			"oracle_bake_ms": oracle.get("bake_ms", 0.0),
			"oracle": MeshAnalyzerScript.strip_transient_arrays(
				oracle_analysis
			),
			"readiness_poll": readiness,
			"immediate_bake": immediate,
			"one_process_frame_bake": one_process_frame,
			"exact": case_exact,
		}
	var report := {
		"ok": all_exact and all_ready_within_limit,
		"purpose": (
			"Measure exact single-body CSG operand availability without "
			+ "changing runtime production code."
		),
		"staging_api": (
			"CSGCombiner3D + presenter._append_csg_body_shape + "
			+ "CSGShape3D.get_meshes/bake_static_mesh"
		),
		"radius_meters": RADIUS_METERS,
		"readiness_frame_pair_limit": READINESS_FRAME_PAIR_LIMIT,
		"immediate_bake_repetitions": IMMEDIATE_BAKE_REPETITIONS,
		"one_process_frame_repetitions": ONE_PROCESS_FRAME_REPETITIONS,
		"synchronous_bake_supported": false,
		"all_exact": all_exact,
		"all_ready_within_limit": all_ready_within_limit,
		"cases": results,
	}
	var json := JSON.stringify(report, "  ", false)
	var output := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	_require(output != null, "could not open result path")
	output.store_string(json + "\n")
	output.close()
	print(json)
	quit(0 if bool(report.get("ok", false)) else 1)


func _build_body(case_id: StringName, points: PackedVector3Array) -> Resource:
	var body: Resource = MaterialBodyScript.new()
	body.body_id = StringName("capsule_readiness_%s" % String(case_id))
	body.body_kind = MaterialBodyScript.BODY_KIND_VOLUME_STROKE
	body.shape_kind = MaterialBodyScript.SHAPE_KIND_CAPSULE_PATH
	body.material_variant_id = MATERIAL_VARIANT_ID
	body.path_points = points
	body.radius_meters = RADIUS_METERS
	var normals := PackedVector3Array()
	var contacts := PackedVector3Array()
	for _point: Vector3 in points:
		normals.append(Vector3.UP)
		contacts.append(Vector3.DOWN)
	body.path_surface_normals = normals
	body.path_contact_directions = contacts
	body.normalize()
	return body


func _build_delayed_oracle(
	presenter: Node,
	body: Resource,
	case_id: String
) -> Dictionary:
	var staging := _create_staging(presenter, body, "%s_oracle" % case_id)
	if not bool(staging.get("ok", false)):
		return staging
	var combiner := staging.get("combiner", null) as CSGCombiner3D
	var wait_start_usec := Time.get_ticks_usec()
	await process_frame
	await physics_frame
	await process_frame
	await physics_frame
	var wait_ms := float(Time.get_ticks_usec() - wait_start_usec) / 1000.0
	var bake_start_usec := Time.get_ticks_usec()
	var baked := combiner.bake_static_mesh()
	var bake_ms := float(Time.get_ticks_usec() - bake_start_usec) / 1000.0
	_destroy_staging(combiner)
	await process_frame
	return {
		"ok": baked != null and baked.get_surface_count() > 0,
		"mesh": baked,
		"bake_ms": bake_ms,
		"wait": {
			"process_frames": 2,
			"physics_frames": 2,
			"wall_ms": wait_ms,
		},
	}


func _probe_readiness(
	presenter: Node,
	body: Resource,
	case_id: String,
	oracle_analysis: Dictionary
) -> Dictionary:
	var staging := _create_staging(presenter, body, "%s_readiness" % case_id)
	if not bool(staging.get("ok", false)):
		return staging
	var combiner := staging.get("combiner", null) as CSGCombiner3D
	var append_done_usec := int(staging.get("append_done_usec", 0))
	var observations: Array = []
	var first_ready_phase := ""
	var first_ready_elapsed_ms := -1.0
	var ready_mesh: ArrayMesh = null
	var immediate := _inspect_generated_meshes(combiner)
	immediate["phase"] = "immediate"
	immediate["elapsed_since_append_ms"] = (
		float(Time.get_ticks_usec() - append_done_usec) / 1000.0
	)
	observations.append(immediate)
	if bool(immediate.get("ready", false)):
		first_ready_phase = "immediate"
		first_ready_elapsed_ms = float(immediate.get(
			"elapsed_since_append_ms",
			0.0
		))
		ready_mesh = immediate.get("mesh", null) as ArrayMesh
	for pair_index in range(1, READINESS_FRAME_PAIR_LIMIT + 1):
		if ready_mesh != null:
			break
		await process_frame
		var after_process := _inspect_generated_meshes(combiner)
		after_process["phase"] = "after_process_%d" % pair_index
		after_process["elapsed_since_append_ms"] = (
			float(Time.get_ticks_usec() - append_done_usec) / 1000.0
		)
		observations.append(after_process)
		if bool(after_process.get("ready", false)):
			first_ready_phase = String(after_process.get("phase", ""))
			first_ready_elapsed_ms = float(after_process.get(
				"elapsed_since_append_ms",
				-1.0
			))
			ready_mesh = after_process.get("mesh", null) as ArrayMesh
			break
		await physics_frame
		var after_physics := _inspect_generated_meshes(combiner)
		after_physics["phase"] = "after_physics_%d" % pair_index
		after_physics["elapsed_since_append_ms"] = (
			float(Time.get_ticks_usec() - append_done_usec) / 1000.0
		)
		observations.append(after_physics)
		if bool(after_physics.get("ready", false)):
			first_ready_phase = String(after_physics.get("phase", ""))
			first_ready_elapsed_ms = float(after_physics.get(
				"elapsed_since_append_ms",
				-1.0
			))
			ready_mesh = after_physics.get("mesh", null) as ArrayMesh
	var bake_start_usec := Time.get_ticks_usec()
	var baked := combiner.bake_static_mesh()
	var bake_ms := float(Time.get_ticks_usec() - bake_start_usec) / 1000.0
	var candidate_mesh: ArrayMesh = (
		ready_mesh if ready_mesh != null else baked
	)
	var comparison := _compare_candidate(candidate_mesh, oracle_analysis)
	var baked_comparison := _compare_candidate(baked, oracle_analysis)
	_destroy_staging(combiner)
	await process_frame
	for observation_variant: Variant in observations:
		var observation := observation_variant as Dictionary
		observation.erase("mesh")
	return {
		"ok": candidate_mesh != null,
		"append_ms": staging.get("append_ms", 0.0),
		"first_ready_phase": first_ready_phase,
		"first_ready_elapsed_ms": first_ready_elapsed_ms,
		"ready_within_frame_pair_limit": ready_mesh != null,
		"observations": observations,
		"post_readiness_bake_ms": bake_ms,
		"get_meshes_candidate_vs_oracle": comparison,
		"baked_candidate_vs_oracle": baked_comparison,
		"exact_geometry": (
			bool(comparison.get("exact", false))
			and bool(baked_comparison.get("exact", false))
		),
	}


func _benchmark_immediate_bake(
	presenter: Node,
	body: Resource,
	case_id: String,
	oracle_analysis: Dictionary
) -> Dictionary:
	var append_times := PackedFloat64Array()
	var bake_times := PackedFloat64Array()
	var total_times := PackedFloat64Array()
	var successful_bakes := 0
	var exact_bakes := 0
	var first_comparison: Dictionary = {}
	for repetition in range(IMMEDIATE_BAKE_REPETITIONS):
		var total_start_usec := Time.get_ticks_usec()
		var staging := _create_staging(
			presenter,
			body,
			"%s_immediate_%03d" % [case_id, repetition]
		)
		_require(bool(staging.get("ok", false)), "immediate staging failed")
		var combiner := staging.get("combiner", null) as CSGCombiner3D
		var bake_start_usec := Time.get_ticks_usec()
		var baked := combiner.bake_static_mesh()
		var bake_ms := float(Time.get_ticks_usec() - bake_start_usec) / 1000.0
		var total_ms := float(Time.get_ticks_usec() - total_start_usec) / 1000.0
		append_times.append(float(staging.get("append_ms", 0.0)))
		bake_times.append(bake_ms)
		total_times.append(total_ms)
		if baked != null and baked.get_surface_count() > 0:
			successful_bakes += 1
			var comparison := _compare_candidate(baked, oracle_analysis)
			if first_comparison.is_empty():
				first_comparison = comparison
			if bool(comparison.get("exact", false)):
				exact_bakes += 1
		_destroy_staging(combiner)
	return {
		"attempt_count": IMMEDIATE_BAKE_REPETITIONS,
		"successful_bake_count": successful_bakes,
		"exact_bake_count": exact_bakes,
		"all_successful_bakes_exact": (
			successful_bakes == IMMEDIATE_BAKE_REPETITIONS
			and exact_bakes == successful_bakes
		),
		"append_ms": _summarize_times(append_times),
		"bake_static_mesh_ms": _summarize_times(bake_times),
		"setup_to_baked_mesh_ms": _summarize_times(total_times),
		"representative_vs_oracle": first_comparison,
	}


func _benchmark_one_process_frame_bake(
	presenter: Node,
	body: Resource,
	case_id: String,
	oracle_analysis: Dictionary
) -> Dictionary:
	var append_times := PackedFloat64Array()
	var append_to_ready_times := PackedFloat64Array()
	var get_meshes_times := PackedFloat64Array()
	var bake_times := PackedFloat64Array()
	var flatten_times := PackedFloat64Array()
	var append_to_packet_times := PackedFloat64Array()
	var ready_count := 0
	var bake_count := 0
	var flatten_count := 0
	var representative_mesh: ArrayMesh = null
	var representative_flatten: Dictionary = {}
	for repetition in range(ONE_PROCESS_FRAME_REPETITIONS):
		var staging := _create_staging(
			presenter,
			body,
			"%s_deferred_%03d" % [case_id, repetition]
		)
		_require(bool(staging.get("ok", false)), "deferred staging failed")
		var combiner := staging.get("combiner", null) as CSGCombiner3D
		var append_done_usec := int(staging.get("append_done_usec", 0))
		await process_frame
		var inspected := _inspect_generated_meshes(combiner)
		var ready_elapsed_ms := (
			float(Time.get_ticks_usec() - append_done_usec) / 1000.0
		)
		append_times.append(float(staging.get("append_ms", 0.0)))
		append_to_ready_times.append(ready_elapsed_ms)
		get_meshes_times.append(float(inspected.get("get_meshes_ms", 0.0)))
		if bool(inspected.get("ready", false)):
			ready_count += 1
		var bake_start_usec := Time.get_ticks_usec()
		var baked := combiner.bake_static_mesh()
		var bake_ms := float(Time.get_ticks_usec() - bake_start_usec) / 1000.0
		bake_times.append(bake_ms)
		if baked != null and baked.get_surface_count() > 0:
			bake_count += 1
			if representative_mesh == null:
				representative_mesh = baked
		var flatten_start_usec := Time.get_ticks_usec()
		var flattened := presenter.call(
			"_flatten_native_protected_handle_baked_mesh",
			baked,
			"capsule_operand_probe_%s" % case_id
		) as Dictionary
		var flatten_ms := (
			float(Time.get_ticks_usec() - flatten_start_usec) / 1000.0
		)
		flatten_times.append(flatten_ms)
		append_to_packet_times.append(
			float(Time.get_ticks_usec() - append_done_usec) / 1000.0
		)
		if bool(flattened.get("ok", false)):
			flatten_count += 1
			if representative_flatten.is_empty():
				representative_flatten = {
					"ok": true,
					"vertex_count": flattened.get("vertex_count", 0),
					"triangle_count": flattened.get("triangle_count", 0),
					"signed_volume_m3": flattened.get("signed_volume_m3", 0.0),
					"packet": flattened,
				}
		_destroy_staging(combiner)
	var representative_comparison := _compare_candidate(
		representative_mesh,
		oracle_analysis
	)
	var native_probe := _probe_native_backend_packet(
		representative_flatten.get("packet", {}) as Dictionary,
		oracle_analysis
	)
	representative_flatten.erase("packet")
	return {
		"attempt_count": ONE_PROCESS_FRAME_REPETITIONS,
		"ready_count": ready_count,
		"successful_bake_count": bake_count,
		"successful_flatten_count": flatten_count,
		"all_generated_packets_ready": (
			ready_count == ONE_PROCESS_FRAME_REPETITIONS
			and bake_count == ONE_PROCESS_FRAME_REPETITIONS
			and flatten_count == ONE_PROCESS_FRAME_REPETITIONS
		),
		"append_ms": _summarize_times(append_times),
		"append_to_get_meshes_ready_ms": _summarize_times(
			append_to_ready_times
		),
		"get_meshes_call_ms": _summarize_times(get_meshes_times),
		"bake_static_mesh_after_ready_ms": _summarize_times(bake_times),
		"flatten_to_indexed_packet_ms": _summarize_times(flatten_times),
		"append_to_indexed_packet_ms": _summarize_times(
			append_to_packet_times
		),
		"representative_vs_oracle": representative_comparison,
		"representative_flattened_packet": representative_flatten,
		"representative_exact_geometry": bool(
			representative_comparison.get("exact", false)
		),
		"native_backend": native_probe,
		"native_backend_accepts_packet": bool(native_probe.get("ok", false)),
	}


func _probe_native_backend_packet(
	packet: Dictionary,
	oracle_analysis: Dictionary
) -> Dictionary:
	if not bool(packet.get("ok", false)):
		return {"ok": false, "reason": "indexed_packet_missing"}
	if not ClassDB.class_exists(&"ForgeV2ManifoldBoolean"):
		return {"ok": false, "reason": "native_backend_unavailable"}
	var backend := ClassDB.instantiate(&"ForgeV2ManifoldBoolean") as Object
	if backend == null or not is_instance_valid(backend):
		return {"ok": false, "reason": "native_backend_instantiation_failed"}
	var vertices := packet.get("vertices", PackedVector3Array()) as PackedVector3Array
	var indices := packet.get("indices", PackedInt32Array()) as PackedInt32Array
	var started_usec := Time.get_ticks_usec()
	var native_result := backend.call("reset_mesh", vertices, indices) as Dictionary
	var call_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	var output_mesh := _build_packet_mesh(
		native_result.get("vertices", PackedVector3Array()) as PackedVector3Array,
		native_result.get("indices", PackedInt32Array()) as PackedInt32Array
	)
	var comparison := _compare_candidate(output_mesh, oracle_analysis)
	backend.call("clear_state")
	return {
		"ok": bool(native_result.get("ok", false)),
		"status": native_result.get("status", ""),
		"error_code": native_result.get("error_code", ""),
		"error_message": native_result.get("error_message", ""),
		"input_winding_reversed": native_result.get(
			"input_winding_reversed",
			false
		),
		"call_wall_ms": call_ms,
		"native_total_ms": native_result.get("total_native_ms", 0.0),
		"native_pack_ms": native_result.get("pack_ms", 0.0),
		"native_import_ms": native_result.get("import_ms", 0.0),
		"native_export_ms": native_result.get("export_ms", 0.0),
		"output_vs_oracle": comparison,
	}


func _build_packet_mesh(
	vertices: PackedVector3Array,
	indices: PackedInt32Array
) -> ArrayMesh:
	if vertices.is_empty() or indices.is_empty() or indices.size() % 3 != 0:
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _create_staging(
	presenter: Node,
	body: Resource,
	suffix: String
) -> Dictionary:
	var combiner := CSGCombiner3D.new()
	combiner.name = "CapsuleOperandStaging_%s" % suffix
	combiner.operation = CSGShape3D.OPERATION_UNION
	combiner.calculate_tangents = false
	combiner.use_collision = false
	combiner.collision_layer = 0
	combiner.collision_mask = 0
	var append_start_usec := Time.get_ticks_usec()
	root.add_child(combiner)
	var appended := bool(presenter.call(
		"_append_csg_body_shape",
		combiner,
		body,
		MATERIAL_VARIANT_ID,
		false,
		0
	))
	var append_done_usec := Time.get_ticks_usec()
	if not appended:
		_destroy_staging(combiner)
		return {"ok": false, "reason": "append_csg_body_shape_failed"}
	return {
		"ok": true,
		"combiner": combiner,
		"append_ms": float(append_done_usec - append_start_usec) / 1000.0,
		"append_done_usec": append_done_usec,
	}


func _destroy_staging(combiner: CSGCombiner3D) -> void:
	if combiner == null or not is_instance_valid(combiner):
		return
	if combiner.get_parent() != null:
		combiner.get_parent().remove_child(combiner)
	combiner.free()


func _inspect_generated_meshes(shape: CSGShape3D) -> Dictionary:
	var start_usec := Time.get_ticks_usec()
	var generated: Array = shape.get_meshes()
	var call_ms := float(Time.get_ticks_usec() - start_usec) / 1000.0
	var types := PackedStringArray()
	var mesh: ArrayMesh = null
	var mesh_transform := Transform3D.IDENTITY
	var has_mesh_transform := false
	for value: Variant in generated:
		if value is Object:
			types.append((value as Object).get_class())
		else:
			types.append(type_string(typeof(value)))
		if value is Transform3D:
			mesh_transform = value as Transform3D
			has_mesh_transform = true
		if value is ArrayMesh:
			var candidate := value as ArrayMesh
			if candidate != null and candidate.get_surface_count() > 0:
				mesh = candidate
	return {
		"ready": mesh != null,
		"get_meshes_ms": call_ms,
		"array_size": generated.size(),
		"element_types": Array(types),
		"has_mesh_transform": has_mesh_transform,
		"mesh_transform_is_identity": (
			has_mesh_transform and mesh_transform.is_equal_approx(
				Transform3D.IDENTITY
			)
		),
		"mesh_transform_origin": [
			mesh_transform.origin.x,
			mesh_transform.origin.y,
			mesh_transform.origin.z,
		],
		"surface_count": mesh.get_surface_count() if mesh != null else 0,
		"mesh": mesh,
	}


func _compare_candidate(
	candidate: ArrayMesh,
	oracle_analysis: Dictionary
) -> Dictionary:
	if candidate == null or candidate.get_surface_count() <= 0:
		return {"ok": false, "exact": false, "reason": "mesh_missing"}
	var candidate_analysis := MeshAnalyzerScript.analyze_mesh(candidate)
	var surface := MeshAnalyzerScript.compare_surfaces(
		candidate_analysis,
		oracle_analysis
	)
	var same_unoriented_signature := (
		String(candidate_analysis.get("geometry_signature_unoriented", ""))
		== String(oracle_analysis.get("geometry_signature_unoriented", ""))
	)
	var same_oriented_signature := (
		String(candidate_analysis.get("geometry_signature_oriented", ""))
		== String(oracle_analysis.get("geometry_signature_oriented", ""))
	)
	return {
		"ok": true,
		"exact": same_unoriented_signature and same_oriented_signature,
		"same_unoriented_signature": same_unoriented_signature,
		"same_oriented_signature": same_oriented_signature,
		"bidirectional_max_meters": surface.get(
			"bidirectional_max_meters",
			INF
		),
		"absolute_volume_delta_cubic_meters": absf(
			float(candidate_analysis.get(
				"absolute_volume_cubic_meters",
				0.0
			))
			- float(oracle_analysis.get(
				"absolute_volume_cubic_meters",
				0.0
			))
		),
		"candidate_surface_count": candidate_analysis.get("surface_count", 0),
		"candidate_vertex_count": candidate_analysis.get(
			"emitted_vertex_count",
			0
		),
		"candidate_triangle_count": candidate_analysis.get(
			"emitted_triangle_count",
			0
		),
		"candidate_signed_volume_cubic_meters": candidate_analysis.get(
			"signed_volume_cubic_meters",
			0.0
		),
	}


func _summarize_times(values: PackedFloat64Array) -> Dictionary:
	if values.is_empty():
		return {}
	var sorted := Array(values)
	sorted.sort()
	var total := 0.0
	for value_variant: Variant in sorted:
		total += float(value_variant)
	return {
		"min": float(sorted[0]),
		"mean": total / float(sorted.size()),
		"p50": _percentile(sorted, 0.50),
		"p95": _percentile(sorted, 0.95),
		"max": float(sorted[sorted.size() - 1]),
	}


func _percentile(sorted: Array, percentile: float) -> float:
	if sorted.is_empty():
		return 0.0
	var index := ceili(percentile * float(sorted.size())) - 1
	return float(sorted[clampi(index, 0, sorted.size() - 1)])


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
