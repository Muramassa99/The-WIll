extends SceneTree

# Tools-only proof for replacing the presenter's interpreted per-index
# SurfaceTool/collision loops with SurfaceTool.create_from_arrays() and
# SurfaceTool.deindex(). This script deliberately does not call TriangleMesh or
# mutate production nodes/files.

const FIXTURE_PATH := "C:/WORKSPACE/godot_runs/forge_v2_exact_regional_fixture_v1.json"
const FIXTURE_FILE_SHA256 := "1fda9d2012131f72a1b3fbec9cb1d1174caf8351662b8f60d1b10ed9d2304415"
const FIXTURE_CANONICAL_SHA256 := "4b92d114ac472a98006bb70131ea28286e2b8689df5a7e2db52df2905a1705a0"
const EXTENSION_PATH := "res://native/forge_v2_manifold/forge_v2_manifold.gdextension"
const RESULT_PATH := "C:/WORKSPACE/godot_runs/verify_forge_v2_bulk_native_publication.json"

# These are the same bounded-workpiece sequence points used by the native
# minute benchmark: reset_mesh establishes the base, then add_mesh calls are
# numbered independently. N=470 previously carried 55,812 collision indices.
const YOUNG_ADD_COUNT := 5
const MATURE_ADD_COUNT := 470
const TRANSLATION_STEP_METERS := 0.004
const WARMUP_COUNT := 2
const MEASURED_COUNT := 16

const TEST_MATERIAL_VARIANT_ID := &"bulk_publication_test_material"
const TEST_BODY_ID := &"bulk_publication_test_body"
const TEST_SURFACE_TARGET_ID := &"bulk_publication_test_surface"
const TEST_NATIVE_REVISION := 470

var _report: Dictionary = {
	"schema": "forge_v2_bulk_native_publication_verify",
	"schema_version": 1,
	"proof_passed": false,
	"production_files_touched": false,
	"triangle_mesh_api_used": false,
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var fixture := _load_fixture()
	if not bool(fixture.get("ok", false)):
		_finish_failure(String(fixture.get("error", "fixture load failed")))
		return
	var extension_resource: Resource = load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(&"ForgeV2ManifoldBoolean"):
		_finish_failure("native extension did not load or register")
		return
	var backend: Object = ClassDB.instantiate(&"ForgeV2ManifoldBoolean")
	if backend == null:
		_finish_failure("native backend could not be instantiated")
		return
	var samples_result := _capture_representative_packets(backend, fixture)
	if not bool(samples_result.get("ok", false)):
		_finish_failure(String(samples_result.get(
			"error", "representative packet generation failed"
		)))
		return
	var samples: Array = samples_result.get("samples", []) as Array
	var sample_reports: Array[Dictionary] = []
	var all_gates_passed := true
	for sample_variant: Variant in samples:
		var sample: Dictionary = sample_variant as Dictionary
		var comparison := _verify_sample(sample)
		sample_reports.append(comparison)
		all_gates_passed = all_gates_passed and bool(comparison.get("proof_passed", false))
	_report.merge({
		"outcome": "pass" if all_gates_passed else "fail",
		"proof_passed": all_gates_passed,
		"fixture": fixture.get("summary", {}),
		"backend": backend.call("get_backend_info"),
		"generation": samples_result.get("generation", {}),
		"sample_reports": sample_reports,
		"timing_scope": {
			"current_path": (
				"index validation, per-index SurfaceTool.add_vertex, index, "
				+ "generate_normals, commit, per-index collision expansion, set_faces"
			),
			"bulk_path": (
				"create_from_arrays, generate_normals, commit, deindex, "
				+ "commit_to_arrays, set_faces"
			),
			"node_staging_and_metadata_excluded_from_timing": true,
			"warmup_count_per_path": WARMUP_COUNT,
			"measured_count_per_path": MEASURED_COUNT,
			"sample_order_alternates": true,
		},
		"scope": {
			"tools_only": true,
			"runtime_presenter_unchanged": true,
			"representative_add_counts": [YOUNG_ADD_COUNT, MATURE_ADD_COUNT],
			"render_equivalence_is_exact_not_approximate": true,
			"collision_equivalence_is_exact_not_approximate": true,
			"triangle_mesh_conversion_is_forbidden": true,
		},
	})
	_write_report()
	print("FORGE_V2_BULK_NATIVE_PUBLICATION_VERIFY: %s" % (
		"PASS" if all_gates_passed else "FAIL"
	))
	for sample_report: Dictionary in sample_reports:
		print(JSON.stringify({
			"sample": sample_report.get("sample", ""),
			"vertices": sample_report.get("native_vertex_count", 0),
			"triangles": sample_report.get("native_triangle_count", 0),
			"current_ms": (
				sample_report.get("timings", {}) as Dictionary
			).get("current_path_ms", {}),
			"bulk_ms": (
				sample_report.get("timings", {}) as Dictionary
			).get("bulk_path_ms", {}),
		}))
	quit(0 if all_gates_passed else 1)


func _capture_representative_packets(backend: Object, fixture: Dictionary) -> Dictionary:
	var base_vertices: PackedVector3Array = fixture.get(
		"base_vertices", PackedVector3Array()
	)
	var base_indices: PackedInt32Array = fixture.get(
		"base_indices", PackedInt32Array()
	)
	var stroke_vertices: PackedVector3Array = fixture.get(
		"stroke_vertices", PackedVector3Array()
	)
	var stroke_indices: PackedInt32Array = fixture.get(
		"stroke_indices", PackedInt32Array()
	)
	var reset_result: Dictionary = backend.call(
		"reset_mesh", base_vertices, base_indices
	) as Dictionary
	if not bool(reset_result.get("ok", false)):
		return {"ok": false, "error": "native reset_mesh failed: %s" % String(
			reset_result.get("error_message", "unknown")
		)}
	var wanted := {
		YOUNG_ADD_COUNT: "young_add_%d" % YOUNG_ADD_COUNT,
		MATURE_ADD_COUNT: "mature_add_%d" % MATURE_ADD_COUNT,
	}
	var samples: Array[Dictionary] = []
	var generation_started_us := Time.get_ticks_usec()
	for add_count in range(1, MATURE_ADD_COUNT + 1):
		var translated_vertices := _translated(
			stroke_vertices,
			_stroke_translation(add_count)
		)
		var native_result: Dictionary = backend.call(
			"add_mesh", translated_vertices, stroke_indices
		) as Dictionary
		if not bool(native_result.get("ok", false)):
			return {
				"ok": false,
				"error": "native add_mesh failed at add %d: %s" % [
					add_count,
					String(native_result.get("error_message", "unknown")),
				],
			}
		if wanted.has(add_count):
			var vertices: PackedVector3Array = native_result.get(
				"vertices", PackedVector3Array()
			)
			var indices: PackedInt32Array = native_result.get(
				"indices", PackedInt32Array()
			)
			var validation := _validate_native_packet(vertices, indices)
			if not bool(validation.get("ok", false)):
				return {
					"ok": false,
					"error": "invalid native packet at add %d: %s" % [
						add_count,
						String(validation.get("error", "unknown")),
					],
				}
			samples.append({
				"label": String(wanted[add_count]),
				"add_count": add_count,
				"native_revision": int(native_result.get("state_revision", -1)),
				"vertices": vertices,
				"indices": indices,
				"packet_sha256": _packet_hash(vertices, indices),
			})
	var generation_ended_us := Time.get_ticks_usec()
	if samples.size() != wanted.size():
		return {"ok": false, "error": "not all representative packets were captured"}
	return {
		"ok": true,
		"samples": samples,
		"generation": {
			"reset_revision": int(reset_result.get("state_revision", -1)),
			"completed_add_count": MATURE_ADD_COUNT,
			"generation_ms": float(generation_ended_us - generation_started_us) / 1000.0,
			"final_state": backend.call("get_state_info"),
		},
	}


func _verify_sample(sample: Dictionary) -> Dictionary:
	var vertices: PackedVector3Array = sample.get("vertices", PackedVector3Array())
	var indices: PackedInt32Array = sample.get("indices", PackedInt32Array())
	var input_validation := _validate_native_packet(vertices, indices)
	var current := _build_current_publication(vertices, indices)
	var bulk := _build_bulk_publication(vertices, indices)
	if not bool(input_validation.get("ok", false)):
		return _failed_sample(sample, String(input_validation.get("error", "invalid input")))
	if not bool(current.get("ok", false)):
		return _failed_sample(sample, "current path failed: %s" % String(
			current.get("error", "unknown")
		))
	if not bool(bulk.get("ok", false)):
		return _failed_sample(sample, "bulk path failed: %s" % String(
			bulk.get("error", "unknown")
		))
	var current_mesh: ArrayMesh = current.get("mesh") as ArrayMesh
	var bulk_mesh: ArrayMesh = bulk.get("mesh") as ArrayMesh
	var current_shape: ConcavePolygonShape3D = current.get("shape") as ConcavePolygonShape3D
	var bulk_shape: ConcavePolygonShape3D = bulk.get("shape") as ConcavePolygonShape3D
	var current_arrays: Array = current_mesh.surface_get_arrays(0)
	var bulk_arrays: Array = bulk_mesh.surface_get_arrays(0)
	var expected_faces := _expand_collision_faces(vertices, indices)
	var current_faces: PackedVector3Array = current.get(
		"faces", PackedVector3Array()
	)
	var bulk_faces: PackedVector3Array = bulk.get("faces", PackedVector3Array())
	var current_shape_faces := current_shape.get_faces()
	var bulk_shape_faces := bulk_shape.get_faces()
	var current_contract := _stage_publication_contract(current_mesh, current_shape)
	var bulk_contract := _stage_publication_contract(bulk_mesh, bulk_shape)
	var timings := _benchmark_paths(vertices, indices)
	var timing_ok := bool(timings.get("ok", false))
	var current_timing: Dictionary = timings.get("current_path_ms", {}) as Dictionary
	var bulk_timing: Dictionary = timings.get("bulk_path_ms", {}) as Dictionary
	var gates := {
		"native_packet_is_finite_indexed_triangles": bool(input_validation.get("ok", false)),
		"both_paths_build_one_triangle_surface": (
			_mesh_is_one_triangle_surface(current_mesh)
			and _mesh_is_one_triangle_surface(bulk_mesh)
		),
		"render_vertex_arrays_are_exact": (
			current_arrays[Mesh.ARRAY_VERTEX] == bulk_arrays[Mesh.ARRAY_VERTEX]
		),
		"render_index_arrays_are_exact": (
			current_arrays[Mesh.ARRAY_INDEX] == bulk_arrays[Mesh.ARRAY_INDEX]
		),
		"render_normal_arrays_are_exact": (
			current_arrays[Mesh.ARRAY_NORMAL] == bulk_arrays[Mesh.ARRAY_NORMAL]
		),
		"all_render_array_slots_are_exact": _mesh_array_slots_are_exact(
			current_arrays, bulk_arrays
		),
		"render_surface_format_and_aabb_are_exact": (
			current_mesh.surface_get_format(0) == bulk_mesh.surface_get_format(0)
			and current_mesh.get_aabb() == bulk_mesh.get_aabb()
		),
		"both_render_normal_sets_are_finite_unit_compatible": (
			_normals_are_finite_nonzero(current_arrays)
			and _normals_are_finite_nonzero(bulk_arrays)
		),
		"current_collision_faces_equal_native_expansion": current_faces == expected_faces,
		"bulk_collision_faces_equal_native_expansion": bulk_faces == expected_faces,
		"current_concave_shape_preserves_exact_faces": current_shape_faces == expected_faces,
		"bulk_concave_shape_preserves_exact_faces": bulk_shape_faces == expected_faces,
		"current_metadata_and_material_contract_is_neutral": bool(
			current_contract.get("ok", false)
		),
		"bulk_metadata_and_material_contract_is_neutral": bool(
			bulk_contract.get("ok", false)
		),
		"metadata_and_material_contracts_are_exact": current_contract == bulk_contract,
		"timing_loops_completed": timing_ok,
		"bulk_mean_is_faster": (
			timing_ok
			and float(bulk_timing.get("mean", INF)) < float(current_timing.get("mean", -INF))
		),
		"bulk_p95_is_faster": (
			timing_ok
			and float(bulk_timing.get("p95", INF)) < float(current_timing.get("p95", -INF))
		),
		"bulk_max_is_faster": (
			timing_ok
			and float(bulk_timing.get("max", INF)) < float(current_timing.get("max", -INF))
		),
	}
	var proof_passed := true
	for gate_value: Variant in gates.values():
		proof_passed = proof_passed and bool(gate_value)
	return {
		"sample": String(sample.get("label", "unknown")),
		"add_count": int(sample.get("add_count", -1)),
		"native_revision": int(sample.get("native_revision", -1)),
		"native_vertex_count": vertices.size(),
		"native_triangle_count": indices.size() / 3,
		"native_index_count": indices.size(),
		"native_packet_sha256": String(sample.get("packet_sha256", "")),
		"proof_passed": proof_passed,
		"gates": gates,
		"render": {
			"current": _render_evidence(current_mesh, current_arrays),
			"bulk": _render_evidence(bulk_mesh, bulk_arrays),
			"differing_array_slots": _differing_mesh_array_slots(
				current_arrays, bulk_arrays
			),
		},
		"collision": {
			"expected_face_count": expected_faces.size(),
			"expected_sha256": _packed_hash(expected_faces),
			"current_packet_sha256": _packed_hash(current_faces),
			"current_shape_sha256": _packed_hash(current_shape_faces),
			"bulk_packet_sha256": _packed_hash(bulk_faces),
			"bulk_shape_sha256": _packed_hash(bulk_shape_faces),
		},
		"publication_contract": current_contract,
		"timings": timings,
	}


func _build_current_publication(
	vertices: PackedVector3Array,
	indices: PackedInt32Array
) -> Dictionary:
	# Mirrors _build_native_static_revision_node() before node construction.
	for index_value: int in indices:
		if index_value < 0 or index_value >= vertices.size():
			return {"ok": false, "error": "index out of range"}
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index_value: int in indices:
		surface_tool.add_vertex(vertices[index_value])
	surface_tool.index()
	surface_tool.generate_normals()
	var render_mesh: ArrayMesh = surface_tool.commit()
	if render_mesh == null or render_mesh.get_surface_count() != 1:
		return {"ok": false, "error": "render mesh build failed"}
	var faces := PackedVector3Array()
	faces.resize(indices.size())
	for index_position in range(indices.size()):
		faces[index_position] = vertices[indices[index_position]]
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = false
	shape.set_faces(faces)
	return {"ok": true, "mesh": render_mesh, "faces": faces, "shape": shape}


func _build_bulk_publication(
	vertices: PackedVector3Array,
	indices: PackedInt32Array
) -> Dictionary:
	# The native extension already validates every exported index. The verifier
	# independently validates once before either candidate is benchmarked.
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var surface_tool := SurfaceTool.new()
	surface_tool.create_from_arrays(arrays, Mesh.PRIMITIVE_TRIANGLES)
	surface_tool.generate_normals()
	var render_mesh: ArrayMesh = surface_tool.commit()
	if render_mesh == null or render_mesh.get_surface_count() != 1:
		return {"ok": false, "error": "render mesh build failed"}
	surface_tool.deindex()
	var collision_arrays: Array = surface_tool.commit_to_arrays()
	if collision_arrays.size() < Mesh.ARRAY_MAX:
		return {"ok": false, "error": "collision arrays are malformed"}
	var collision_vertex_variant: Variant = collision_arrays[Mesh.ARRAY_VERTEX]
	if not (collision_vertex_variant is PackedVector3Array):
		return {"ok": false, "error": "collision vertices are missing"}
	var faces: PackedVector3Array = collision_vertex_variant as PackedVector3Array
	if faces.size() != indices.size():
		return {"ok": false, "error": "deindexed collision face count changed"}
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = false
	shape.set_faces(faces)
	return {"ok": true, "mesh": render_mesh, "faces": faces, "shape": shape}


func _stage_publication_contract(
	mesh: ArrayMesh,
	shape: ConcavePolygonShape3D
) -> Dictionary:
	var revision_node := Node3D.new()
	revision_node.name = "NativeStaticMaterialBodyRevision_000470"
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "NativeStaticMaterialBodyMesh"
	var collision_body := StaticBody3D.new()
	collision_body.name = "NativeStaticMaterialBodyCollision"
	var collision_node := CollisionShape3D.new()
	collision_node.name = "NativeStaticMaterialBodyShape"
	for metadata_node: Node in [revision_node, mesh_instance, collision_body]:
		metadata_node.set_meta("forge_v2_material_surface", false)
		metadata_node.set_meta("forge_v2_material_variant_id", TEST_MATERIAL_VARIANT_ID)
		metadata_node.set_meta("forge_v2_body_id", TEST_BODY_ID)
		metadata_node.set_meta("forge_v2_surface_target_id", TEST_SURFACE_TARGET_ID)
		metadata_node.set_meta("forge_v2_publication_pending", true)
		metadata_node.set_meta("forge_v2_native_revision", TEST_NATIVE_REVISION)
	var metadata_before := _metadata_snapshot([
		revision_node, mesh_instance, collision_body,
	])
	var material := _build_test_material()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	collision_node.shape = shape
	collision_body.collision_layer = 0
	collision_body.collision_mask = 0
	collision_body.add_child(collision_node)
	revision_node.add_child(mesh_instance)
	revision_node.add_child(collision_body)
	revision_node.visible = false
	var metadata_after := _metadata_snapshot([
		revision_node, mesh_instance, collision_body,
	])
	var expected_metadata := _expected_metadata_snapshot()
	var material_ok := (
		mesh_instance.material_override == material
		and mesh.surface_get_material(0) == null
		and material.albedo_color.is_equal_approx(
			Color(0.24, 0.52, 0.82, 1.0)
		)
		and material.emission_enabled
		and material.emission.is_equal_approx(Color(0.02, 0.04, 0.08, 1.0))
		and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
		and material.cull_mode == BaseMaterial3D.CULL_DISABLED
		and is_equal_approx(material.roughness, 0.54)
		and is_equal_approx(material.metallic, 0.12)
	)
	var node_contract_ok := (
		not revision_node.visible
		and mesh_instance.mesh == mesh
		and collision_node.shape == shape
		and collision_body.collision_layer == 0
		and collision_body.collision_mask == 0
		and revision_node.transform == Transform3D.IDENTITY
		and mesh_instance.transform == Transform3D.IDENTITY
		and collision_body.transform == Transform3D.IDENTITY
		and collision_node.transform == Transform3D.IDENTITY
	)
	var resources_are_metadata_neutral := (
		mesh.get_meta_list().is_empty()
		and shape.get_meta_list().is_empty()
	)
	var result := {
		"ok": (
			metadata_before == metadata_after
			and metadata_after == expected_metadata
			and material_ok
			and node_contract_ok
			and resources_are_metadata_neutral
		),
		"metadata_unchanged_by_resource_assignment": metadata_before == metadata_after,
		"metadata_matches_presenter_staging_contract": metadata_after == expected_metadata,
		"material_override_compatible": material_ok,
		"node_contract_compatible": node_contract_ok,
		"mesh_and_shape_have_no_metadata": resources_are_metadata_neutral,
		"metadata_sha256": var_to_bytes(metadata_after).hex_encode().sha256_text(),
	}
	revision_node.free()
	return result


func _benchmark_paths(
	vertices: PackedVector3Array,
	indices: PackedInt32Array
) -> Dictionary:
	for _warmup_index in range(WARMUP_COUNT):
		var current_warmup := _build_current_publication(vertices, indices)
		var bulk_warmup := _build_bulk_publication(vertices, indices)
		if not bool(current_warmup.get("ok", false)) or not bool(bulk_warmup.get("ok", false)):
			return {"ok": false, "error": "publication warmup failed"}
	var current_ms: Array[float] = []
	var bulk_ms: Array[float] = []
	for sample_index in range(MEASURED_COUNT):
		if sample_index % 2 == 0:
			var current_first := _timed_build(false, vertices, indices)
			var bulk_second := _timed_build(true, vertices, indices)
			if not bool(current_first.get("ok", false)) or not bool(bulk_second.get("ok", false)):
				return {"ok": false, "error": "publication timing build failed"}
			current_ms.append(float(current_first.get("elapsed_ms", INF)))
			bulk_ms.append(float(bulk_second.get("elapsed_ms", INF)))
		else:
			var bulk_first := _timed_build(true, vertices, indices)
			var current_second := _timed_build(false, vertices, indices)
			if not bool(current_second.get("ok", false)) or not bool(bulk_first.get("ok", false)):
				return {"ok": false, "error": "publication timing build failed"}
			current_ms.append(float(current_second.get("elapsed_ms", INF)))
			bulk_ms.append(float(bulk_first.get("elapsed_ms", INF)))
	var current_summary := _summarize(current_ms)
	var bulk_summary := _summarize(bulk_ms)
	var current_mean := float(current_summary.get("mean", INF))
	var bulk_mean := float(bulk_summary.get("mean", INF))
	return {
		"ok": current_ms.size() == MEASURED_COUNT and bulk_ms.size() == MEASURED_COUNT,
		"current_path_ms": current_summary,
		"bulk_path_ms": bulk_summary,
		"bulk_vs_current_mean_ratio": (
			bulk_mean / current_mean if current_mean > 0.0 else INF
		),
		"mean_saved_ms": current_mean - bulk_mean,
		"mean_reduction_percent": (
			(current_mean - bulk_mean) * 100.0 / current_mean
			if current_mean > 0.0
			else -INF
		),
	}


func _timed_build(
	bulk: bool,
	vertices: PackedVector3Array,
	indices: PackedInt32Array
) -> Dictionary:
	var started_us := Time.get_ticks_usec()
	var result := (
		_build_bulk_publication(vertices, indices)
		if bulk
		else _build_current_publication(vertices, indices)
	)
	var ended_us := Time.get_ticks_usec()
	return {
		"ok": bool(result.get("ok", false)),
		"elapsed_ms": float(ended_us - started_us) / 1000.0,
	}


func _validate_native_packet(
	vertices: PackedVector3Array,
	indices: PackedInt32Array
) -> Dictionary:
	if vertices.is_empty():
		return {"ok": false, "error": "vertices are empty"}
	if indices.is_empty() or indices.size() % 3 != 0:
		return {"ok": false, "error": "indices are not complete triangles"}
	for vertex: Vector3 in vertices:
		if not vertex.is_finite():
			return {"ok": false, "error": "vertex is non-finite"}
	for index_value: int in indices:
		if index_value < 0 or index_value >= vertices.size():
			return {"ok": false, "error": "index is out of range"}
	return {"ok": true}


func _mesh_is_one_triangle_surface(mesh: ArrayMesh) -> bool:
	return (
		mesh != null
		and mesh.get_surface_count() == 1
		and mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES
		and (mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_VERTEX) != 0
		and (mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_NORMAL) != 0
		and (mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_INDEX) != 0
	)


func _normals_are_finite_nonzero(arrays: Array) -> bool:
	if arrays.size() < Mesh.ARRAY_MAX:
		return false
	var vertex_variant: Variant = arrays[Mesh.ARRAY_VERTEX]
	var normal_variant: Variant = arrays[Mesh.ARRAY_NORMAL]
	if not (vertex_variant is PackedVector3Array) or not (normal_variant is PackedVector3Array):
		return false
	var vertices: PackedVector3Array = vertex_variant as PackedVector3Array
	var normals: PackedVector3Array = normal_variant as PackedVector3Array
	if normals.size() != vertices.size() or normals.is_empty():
		return false
	for normal: Vector3 in normals:
		if not normal.is_finite() or normal.length_squared() <= 0.5:
			return false
	return true


func _mesh_array_slots_are_exact(first: Array, second: Array) -> bool:
	if first.size() != second.size():
		return false
	for slot in range(first.size()):
		if typeof(first[slot]) != typeof(second[slot]) or first[slot] != second[slot]:
			return false
	return true


func _differing_mesh_array_slots(first: Array, second: Array) -> Array[int]:
	var result: Array[int] = []
	for slot in range(maxi(first.size(), second.size())):
		if slot >= first.size() or slot >= second.size():
			result.append(slot)
			continue
		if typeof(first[slot]) != typeof(second[slot]) or first[slot] != second[slot]:
			result.append(slot)
	return result


func _render_evidence(mesh: ArrayMesh, arrays: Array) -> Dictionary:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	return {
		"vertex_count": vertices.size(),
		"normal_count": normals.size(),
		"index_count": indices.size(),
		"triangle_count": indices.size() / 3,
		"surface_format": mesh.surface_get_format(0),
		"primitive": mesh.surface_get_primitive_type(0),
		"vertices_sha256": _packed_hash(vertices),
		"normals_sha256": _packed_hash(normals),
		"indices_sha256": _packed_hash(indices),
		"all_arrays_sha256": _packed_hash(arrays),
		"aabb_position": _vector3_array(mesh.get_aabb().position),
		"aabb_size": _vector3_array(mesh.get_aabb().size),
	}


func _expand_collision_faces(
	vertices: PackedVector3Array,
	indices: PackedInt32Array
) -> PackedVector3Array:
	var faces := PackedVector3Array()
	faces.resize(indices.size())
	for index_position in range(indices.size()):
		faces[index_position] = vertices[indices[index_position]]
	return faces


func _build_test_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.52, 0.82, 1.0)
	material.roughness = 0.54
	material.metallic = 0.12
	material.emission_enabled = true
	material.emission = Color(0.02, 0.04, 0.08, 1.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _metadata_snapshot(nodes: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node_variant: Variant in nodes:
		var node := node_variant as Node
		var metadata: Dictionary = {}
		var names := PackedStringArray()
		for metadata_name: StringName in node.get_meta_list():
			names.append(String(metadata_name))
		names.sort()
		for metadata_name: String in names:
			var value: Variant = node.get_meta(metadata_name)
			metadata[metadata_name] = (
				String(value) if value is StringName else value
			)
		result.append({"node_name": String(node.name), "metadata": metadata})
	return result


func _expected_metadata_snapshot() -> Array[Dictionary]:
	var metadata := {
		"forge_v2_body_id": String(TEST_BODY_ID),
		"forge_v2_material_surface": false,
		"forge_v2_material_variant_id": String(TEST_MATERIAL_VARIANT_ID),
		"forge_v2_native_revision": TEST_NATIVE_REVISION,
		"forge_v2_publication_pending": true,
		"forge_v2_surface_target_id": String(TEST_SURFACE_TARGET_ID),
	}
	return [
		{"node_name": "NativeStaticMaterialBodyRevision_000470", "metadata": metadata.duplicate()},
		{"node_name": "NativeStaticMaterialBodyMesh", "metadata": metadata.duplicate()},
		{"node_name": "NativeStaticMaterialBodyCollision", "metadata": metadata.duplicate()},
	]


func _load_fixture() -> Dictionary:
	if not FileAccess.file_exists(FIXTURE_PATH):
		return {"ok": false, "error": "exact fixture is missing"}
	if FileAccess.get_sha256(FIXTURE_PATH).to_lower() != FIXTURE_FILE_SHA256:
		return {"ok": false, "error": "exact fixture file SHA256 mismatch"}
	var file := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	if not (parsed is Dictionary):
		return {"ok": false, "error": "exact fixture JSON is invalid"}
	var fixture := parsed as Dictionary
	if String(fixture.get("canonical_sha256", "")) != FIXTURE_CANONICAL_SHA256:
		return {"ok": false, "error": "exact fixture canonical hash mismatch"}
	var packets: Dictionary = fixture.get("packets", {}) as Dictionary
	var base := _packet_arrays(packets.get("stroke_a", {}) as Dictionary)
	var stroke := _packet_arrays(packets.get("stroke_b", {}) as Dictionary)
	if not bool(base.get("ok", false)) or not bool(stroke.get("ok", false)):
		return {"ok": false, "error": "fixture packet conversion failed"}
	return {
		"ok": true,
		"base_vertices": base.get("vertices"),
		"base_indices": base.get("indices"),
		"stroke_vertices": stroke.get("vertices"),
		"stroke_indices": stroke.get("indices"),
		"summary": {
			"path": FIXTURE_PATH,
			"file_sha256": FIXTURE_FILE_SHA256,
			"canonical_sha256": FIXTURE_CANONICAL_SHA256,
		},
	}


func _packet_arrays(packet: Dictionary) -> Dictionary:
	var vertices := PackedVector3Array()
	for value: Variant in packet.get("vertices", []) as Array:
		if not (value is Array) or (value as Array).size() != 3:
			return {"ok": false}
		var coordinate := value as Array
		vertices.append(Vector3(
			float(coordinate[0]), float(coordinate[1]), float(coordinate[2])
		))
	var indices := PackedInt32Array()
	for value: Variant in packet.get("triangles", []) as Array:
		if not (value is Dictionary):
			return {"ok": false}
		var triangle: Array = (value as Dictionary).get("indices", []) as Array
		if triangle.size() != 3:
			return {"ok": false}
		indices.append(int(triangle[0]))
		indices.append(int(triangle[1]))
		indices.append(int(triangle[2]))
	return {"ok": true, "vertices": vertices, "indices": indices}


func _translated(
	vertices: PackedVector3Array,
	translation: Vector3
) -> PackedVector3Array:
	var result := PackedVector3Array()
	result.resize(vertices.size())
	for index in range(vertices.size()):
		result[index] = vertices[index] + translation
	return result


func _stroke_translation(add_count: int) -> Vector3:
	return Vector3(
		float((add_count - 1) % 48) * TRANSLATION_STEP_METERS,
		0.004 * sin(float(add_count) * TAU * 0.61803398875),
		0.003 * cos(float(add_count) * TAU * 0.41421356237)
	)


func _summarize(values: Array[float]) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value: float in sorted:
		total += value
	return {
		"count": sorted.size(),
		"min": sorted[0] if not sorted.is_empty() else INF,
		"mean": total / float(sorted.size()) if not sorted.is_empty() else INF,
		"p50": _percentile(sorted, 0.50),
		"p95": _percentile(sorted, 0.95),
		"p99": _percentile(sorted, 0.99),
		"max": sorted[-1] if not sorted.is_empty() else INF,
	}


func _percentile(sorted: Array[float], fraction: float) -> float:
	if sorted.is_empty():
		return INF
	return sorted[int(ceil(fraction * float(sorted.size()))) - 1]


func _packet_hash(
	vertices: PackedVector3Array,
	indices: PackedInt32Array
) -> String:
	return var_to_bytes([vertices, indices]).hex_encode().sha256_text()


func _packed_hash(value: Variant) -> String:
	return var_to_bytes(value).hex_encode().sha256_text()


func _vector3_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _failed_sample(sample: Dictionary, message: String) -> Dictionary:
	return {
		"sample": String(sample.get("label", "unknown")),
		"add_count": int(sample.get("add_count", -1)),
		"proof_passed": false,
		"failure_reason": message,
	}


func _finish_failure(message: String) -> void:
	_report["outcome"] = "fail"
	_report["proof_passed"] = false
	_report["failure_reason"] = message
	_write_report()
	push_error("FORGE_V2_BULK_NATIVE_PUBLICATION_VERIFY: %s" % message)
	quit(1)


func _write_report() -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report, "\t"))
