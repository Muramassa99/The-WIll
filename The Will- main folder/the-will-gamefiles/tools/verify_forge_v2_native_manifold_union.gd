extends SceneTree

const FIXTURE_PATH := "C:/WORKSPACE/godot_runs/forge_v2_exact_regional_fixture_v1.json"
const RESULT_PATH := "C:/WORKSPACE/godot_runs/verify_forge_v2_native_manifold_union.json"
const EXTENSION_PATH := "res://native/forge_v2_manifold/forge_v2_manifold.gdextension"
const FIXTURE_CANONICAL_SHA256 := "4b92d114ac472a98006bb70131ea28286e2b8689df5a7e2db52df2905a1705a0"
const STROKE_A_SHA256 := "b12f224e65a17c7888e6b13eab13b812a7cf8b65f10f0b49569391642449afb8"
const STROKE_B_SHA256 := "8c8d1103c669322eac75cd92e3bd91faaca84e67d643f5020f95aa4b720cdbf7"
const EXPECTED_VERTEX_COUNT := 868
const EXPECTED_TRIANGLE_COUNT := 1732
const EXPECTED_SOURCE_A_TRIANGLES := 1488
const EXPECTED_SOURCE_B_TRIANGLES := 244
const EXPECTED_VOLUME_M3 := 0.0002702395070420351
const EXPECTED_BOUNDS_MIN := Vector3(
	-0.18512099981307983,
	-0.03458040952682495,
	-0.018253665417432785
)
const EXPECTED_BOUNDS_MAX := Vector3(
	0.18813760578632355,
	0.039870698004961014,
	0.03969673812389374
)
const WARMUP_COUNT := 5
const MEASURED_COUNT := 30
const EXTERNAL_P95_LIMIT_MS := 25.0
const EXTERNAL_MAX_LIMIT_MS := 50.0
const BOUNDS_TOLERANCE_M := 0.00001
const VOLUME_TOLERANCE_M3 := 0.0000000005
const COLLISION_LAYER := 1 << 19
const PHYSICS_PROBE_COUNT := 12

var _report: Dictionary = {
	"schema": "forge_v2_native_manifold_union_verify",
	"schema_version": 1,
	"proof_passed": false,
	"production_files_touched": false,
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var fixture_result := _load_fixture()
	if not bool(fixture_result.get("ok", false)):
		_finish_failure(String(fixture_result.get("error", "fixture load failed")))
		return
	var stroke_a: Dictionary = fixture_result.get("stroke_a", {}) as Dictionary
	var stroke_b: Dictionary = fixture_result.get("stroke_b", {}) as Dictionary
	var a_vertices: PackedVector3Array = stroke_a.get("vertices", PackedVector3Array())
	var a_indices: PackedInt32Array = stroke_a.get("indices", PackedInt32Array())
	var b_vertices: PackedVector3Array = stroke_b.get("vertices", PackedVector3Array())
	var b_indices: PackedInt32Array = stroke_b.get("indices", PackedInt32Array())
	var input_hash_before := _packet_hash(a_vertices, a_indices, b_vertices, b_indices)

	var extension_resource: Resource = load(EXTENSION_PATH)
	if extension_resource == null:
		_finish_failure("native GDExtension resource did not load")
		return
	if not ClassDB.class_exists(&"ForgeV2ManifoldBoolean"):
		_finish_failure("ForgeV2ManifoldBoolean was not registered")
		return
	var backend: Object = ClassDB.instantiate(&"ForgeV2ManifoldBoolean")
	if backend == null:
		_finish_failure("ForgeV2ManifoldBoolean could not be instantiated")
		return
	var backend_info: Dictionary = backend.call("get_backend_info") as Dictionary

	for _warmup_index in range(WARMUP_COUNT):
		var warmup: Dictionary = backend.call(
			"union_meshes",
			a_vertices,
			a_indices,
			b_vertices,
			b_indices
		) as Dictionary
		if not bool(warmup.get("ok", false)):
			_finish_failure(
				"native warmup failed: %s" % String(warmup.get("error_message", "unknown"))
			)
			return

	var external_ms: Array[float] = []
	var boolean_ms: Array[float] = []
	var export_ms: Array[float] = []
	var total_native_ms: Array[float] = []
	var output_hashes: Dictionary = {}
	var final_result: Dictionary = {}
	for _sample_index in range(MEASURED_COUNT):
		var call_started := Time.get_ticks_usec()
		var native_result: Dictionary = backend.call(
			"union_meshes",
			a_vertices,
			a_indices,
			b_vertices,
			b_indices
		) as Dictionary
		var call_ended := Time.get_ticks_usec()
		if not bool(native_result.get("ok", false)):
			_finish_failure(
				"native measured call failed: %s" % String(
					native_result.get("error_message", "unknown")
				)
			)
			return
		external_ms.append(float(call_ended - call_started) / 1000.0)
		boolean_ms.append(float(native_result.get("boolean_ms", INF)))
		export_ms.append(float(native_result.get("export_ms", INF)))
		total_native_ms.append(float(native_result.get("total_native_ms", INF)))
		var output_vertices: PackedVector3Array = native_result.get(
			"vertices", PackedVector3Array()
		)
		var output_indices: PackedInt32Array = native_result.get(
			"indices", PackedInt32Array()
		)
		var output_hash := _single_packet_hash(output_vertices, output_indices)
		output_hashes[output_hash] = int(output_hashes.get(output_hash, 0)) + 1
		final_result = native_result

	var input_hash_after := _packet_hash(a_vertices, a_indices, b_vertices, b_indices)
	var output_vertices: PackedVector3Array = final_result.get(
		"vertices", PackedVector3Array()
	)
	var output_indices: PackedInt32Array = final_result.get(
		"indices", PackedInt32Array()
	)
	var output_sources: PackedInt32Array = final_result.get(
		"source_original_ids", PackedInt32Array()
	)
	var geometry := _analyze_output(output_vertices, output_indices, output_sources)
	var publication := await _publish_and_probe(output_vertices, output_indices)
	var latency := {
		"warmup_count": WARMUP_COUNT,
		"measured_count": MEASURED_COUNT,
		"external_call_ms": _summarize(external_ms),
		"native_boolean_ms": _summarize(boolean_ms),
		"native_export_ms": _summarize(export_ms),
		"native_total_ms": _summarize(total_native_ms),
	}
	var external_summary: Dictionary = latency.get("external_call_ms", {}) as Dictionary
	var gates := {
		"backend_is_pinned_manifold_3_3_2": (
			String(backend_info.get("manifold_version", "")) == "3.3.2"
			and not bool(backend_info.get("parallel", true))
		),
		"all_calls_returned_one_deterministic_packet": output_hashes.size() == 1,
		"input_packets_are_unchanged": input_hash_before == input_hash_after,
		"native_status_is_no_error": String(final_result.get("status", "")) == "NoError",
		"both_established_godot_inputs_reversed_once": (
			bool(final_result.get("input_a_winding_reversed", false))
			and bool(final_result.get("input_b_winding_reversed", false))
		),
		"oracle_vertex_and_triangle_counts_match": (
			int(geometry.get("vertex_count", 0)) == EXPECTED_VERTEX_COUNT
			and int(geometry.get("triangle_count", 0)) == EXPECTED_TRIANGLE_COUNT
		),
		"all_output_triangles_are_finite_nonzero_and_indexed": (
			int(geometry.get("invalid_index_count", -1)) == 0
			and int(geometry.get("nonfinite_vertex_count", -1)) == 0
			and int(geometry.get("zero_area_triangle_count", -1)) == 0
		),
		"godot_winding_and_oracle_volume_match": (
			float(geometry.get("signed_volume_m3", 0.0)) < 0.0
			and absf(float(geometry.get("absolute_volume_m3", 0.0)) - EXPECTED_VOLUME_M3)
			<= VOLUME_TOLERANCE_M3
		),
		"oracle_bounds_match": float(geometry.get("bounds_max_delta_m", INF)) <= BOUNDS_TOLERANCE_M,
		"organic_source_provenance_counts_match": (
			int(geometry.get("source_a_triangle_count", -1)) == EXPECTED_SOURCE_A_TRIANGLES
			and int(geometry.get("source_b_triangle_count", -1)) == EXPECTED_SOURCE_B_TRIANGLES
			and int(geometry.get("unknown_source_triangle_count", -1)) == 0
		),
		"arraymesh_and_concave_packet_roundtrip": bool(publication.get("packet_roundtrip_ok", false)),
		"robust_physics_surface_probes_hit": bool(publication.get("physics_probes_ok", false)),
		"external_union_p95_is_at_most_25_ms": float(external_summary.get("p95", INF)) <= EXTERNAL_P95_LIMIT_MS,
		"external_union_max_is_at_most_50_ms": float(external_summary.get("max", INF)) <= EXTERNAL_MAX_LIMIT_MS,
	}
	var proof_passed := true
	for gate_value: Variant in gates.values():
		proof_passed = proof_passed and bool(gate_value)
	_report.merge({
		"outcome": "pass" if proof_passed else "fail",
		"proof_passed": proof_passed,
		"fixture": fixture_result.get("summary", {}),
		"backend": backend_info,
		"native_result_summary": _strip_packet_arrays(final_result),
		"geometry": geometry,
		"publication": publication,
		"latency": latency,
		"deterministic_output_hashes": output_hashes,
		"gates": gates,
		"scope": {
			"tools_only_native_union_proof": true,
			"production_cutover_performed": false,
			"regional_state_or_async_implemented": false,
		},
	}, true)
	_write_report()
	if proof_passed:
		print("FORGE_V2_NATIVE_MANIFOLD_UNION_VERIFY: PASS")
		print(JSON.stringify({
			"external_ms": external_summary,
			"boolean_ms": latency.get("native_boolean_ms", {}),
			"export_ms": latency.get("native_export_ms", {}),
			"triangles": geometry.get("triangle_count", 0),
			"physics_hits": publication.get("physics_hit_count", 0),
		}))
		quit(0)
	else:
		push_error("FORGE_V2_NATIVE_MANIFOLD_UNION_VERIFY: FAIL")
		quit(1)


func _load_fixture() -> Dictionary:
	if not FileAccess.file_exists(FIXTURE_PATH):
		return {"ok": false, "error": "exact fixture is missing"}
	var file := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "exact fixture could not be opened"}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {"ok": false, "error": "exact fixture JSON is invalid"}
	var fixture := parsed as Dictionary
	var packets: Dictionary = fixture.get("packets", {}) as Dictionary
	var packet_a: Dictionary = packets.get("stroke_a", {}) as Dictionary
	var packet_b: Dictionary = packets.get("stroke_b", {}) as Dictionary
	if (
		String(fixture.get("canonical_sha256", "")) != FIXTURE_CANONICAL_SHA256
		or String(packet_a.get("canonical_sha256", "")) != STROKE_A_SHA256
		or String(packet_b.get("canonical_sha256", "")) != STROKE_B_SHA256
	):
		return {"ok": false, "error": "exact fixture canonical hash mismatch"}
	var converted_a := _convert_packet(packet_a)
	var converted_b := _convert_packet(packet_b)
	if not bool(converted_a.get("ok", false)) or not bool(converted_b.get("ok", false)):
		return {"ok": false, "error": "exact fixture packet conversion failed"}
	return {
		"ok": true,
		"stroke_a": converted_a,
		"stroke_b": converted_b,
		"summary": {
			"path": FIXTURE_PATH,
			"canonical_sha256": FIXTURE_CANONICAL_SHA256,
			"stroke_a_sha256": STROKE_A_SHA256,
			"stroke_b_sha256": STROKE_B_SHA256,
		},
	}


func _convert_packet(packet: Dictionary) -> Dictionary:
	var vertices := PackedVector3Array()
	for value: Variant in packet.get("vertices", []) as Array:
		if not (value is Array) or (value as Array).size() != 3:
			return {"ok": false}
		var coordinates := value as Array
		vertices.append(Vector3(
			float(coordinates[0]), float(coordinates[1]), float(coordinates[2])
		))
	var indices := PackedInt32Array()
	for value: Variant in packet.get("triangles", []) as Array:
		if not (value is Dictionary):
			return {"ok": false}
		var triangle_indices: Array = (value as Dictionary).get("indices", []) as Array
		if triangle_indices.size() != 3:
			return {"ok": false}
		indices.append(int(triangle_indices[0]))
		indices.append(int(triangle_indices[1]))
		indices.append(int(triangle_indices[2]))
	return {"ok": true, "vertices": vertices, "indices": indices}


func _analyze_output(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	sources: PackedInt32Array
) -> Dictionary:
	var nonfinite_vertices := 0
	var invalid_indices := 0
	var zero_area := 0
	var signed_volume := 0.0
	var bounds := AABB()
	var has_bounds := false
	for vertex: Vector3 in vertices:
		if not vertex.is_finite():
			nonfinite_vertices += 1
			continue
		bounds = AABB(vertex, Vector3.ZERO) if not has_bounds else bounds.expand(vertex)
		has_bounds = true
	for triangle in range(indices.size() / 3):
		var a_index := indices[triangle * 3]
		var b_index := indices[triangle * 3 + 1]
		var c_index := indices[triangle * 3 + 2]
		if (
			a_index < 0 or b_index < 0 or c_index < 0
			or a_index >= vertices.size() or b_index >= vertices.size() or c_index >= vertices.size()
		):
			invalid_indices += 1
			continue
		var a := vertices[a_index]
		var b := vertices[b_index]
		var c := vertices[c_index]
		var cross := (b - a).cross(c - a)
		if not cross.is_finite() or cross.length_squared() <= 0.0:
			zero_area += 1
			continue
		signed_volume += a.dot(b.cross(c)) / 6.0
	var source_a_count := sources.count(0)
	var source_b_count := sources.count(1)
	var unknown_count := sources.size() - source_a_count - source_b_count
	var bounds_delta := INF
	if has_bounds:
		var actual_max := bounds.position + bounds.size
		bounds_delta = maxf(
			_max_abs_component(bounds.position - EXPECTED_BOUNDS_MIN),
			_max_abs_component(actual_max - EXPECTED_BOUNDS_MAX)
		)
	return {
		"vertex_count": vertices.size(),
		"triangle_count": indices.size() / 3,
		"nonfinite_vertex_count": nonfinite_vertices,
		"invalid_index_count": invalid_indices,
		"zero_area_triangle_count": zero_area,
		"signed_volume_m3": signed_volume,
		"absolute_volume_m3": absf(signed_volume),
		"bounds_position": _vector_array(bounds.position),
		"bounds_size": _vector_array(bounds.size),
		"bounds_max_delta_m": bounds_delta,
		"source_a_triangle_count": source_a_count,
		"source_b_triangle_count": source_b_count,
		"unknown_source_triangle_count": unknown_count,
	}


func _publish_and_probe(
	vertices: PackedVector3Array,
	indices: PackedInt32Array
) -> Dictionary:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var roundtrip_arrays: Array = mesh.surface_get_arrays(0)
	var roundtrip_vertices: PackedVector3Array = roundtrip_arrays[Mesh.ARRAY_VERTEX]
	var roundtrip_indices: PackedInt32Array = roundtrip_arrays[Mesh.ARRAY_INDEX]

	var faces := PackedVector3Array()
	faces.resize(indices.size())
	for index_position in range(indices.size()):
		faces[index_position] = vertices[indices[index_position]]
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	body.collision_layer = COLLISION_LAYER
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	await process_frame
	await physics_frame
	await process_frame
	await physics_frame

	var candidates: Array[int] = []
	for triangle in range(indices.size() / 3):
		var a := vertices[indices[triangle * 3]]
		var b := vertices[indices[triangle * 3 + 1]]
		var c := vertices[indices[triangle * 3 + 2]]
		if (b - a).cross(c - a).length_squared() > 0.000000000001:
			candidates.append(triangle)
	var hit_count := 0
	var selected_count := mini(PHYSICS_PROBE_COUNT, candidates.size())
	for probe_index in range(selected_count):
		var candidate_offset := int(floor(
			float(probe_index) * float(candidates.size()) / float(selected_count)
		))
		var triangle := candidates[mini(candidate_offset, candidates.size() - 1)]
		var a := vertices[indices[triangle * 3]]
		var b := vertices[indices[triangle * 3 + 1]]
		var c := vertices[indices[triangle * 3 + 2]]
		var normal := (b - a).cross(c - a).normalized()
		var center := (a + b + c) / 3.0
		var query := PhysicsRayQueryParameters3D.create(
			center + normal * 0.003,
			center - normal * 0.003,
			COLLISION_LAYER
		)
		query.hit_back_faces = true
		query.hit_from_inside = true
		var hit: Dictionary = root.world_3d.direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.get("collider") == body:
			hit_count += 1
	var shape_faces := shape.get_faces()
	body.queue_free()
	return {
		"arraymesh_vertex_count": roundtrip_vertices.size(),
		"arraymesh_index_count": roundtrip_indices.size(),
		"concave_face_vertex_count": shape_faces.size(),
		"packet_roundtrip_ok": (
			roundtrip_vertices == vertices
			and roundtrip_indices == indices
			and shape_faces.size() == faces.size()
		),
		"physics_probe_count": selected_count,
		"physics_hit_count": hit_count,
		"physics_probes_ok": selected_count == PHYSICS_PROBE_COUNT and hit_count == selected_count,
	}


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


func _single_packet_hash(vertices: PackedVector3Array, indices: PackedInt32Array) -> String:
	return var_to_bytes([vertices, indices]).hex_encode().sha256_text()


func _packet_hash(
	a_vertices: PackedVector3Array,
	a_indices: PackedInt32Array,
	b_vertices: PackedVector3Array,
	b_indices: PackedInt32Array
) -> String:
	return var_to_bytes([
		a_vertices,
		a_indices,
		b_vertices,
		b_indices,
	]).hex_encode().sha256_text()


func _strip_packet_arrays(native_result: Dictionary) -> Dictionary:
	var summary := native_result.duplicate(false)
	summary.erase("vertices")
	summary.erase("indices")
	summary.erase("source_original_ids")
	summary.erase("source_face_ids")
	return summary


func _vector_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _max_abs_component(value: Vector3) -> float:
	var absolute := value.abs()
	return maxf(absolute.x, maxf(absolute.y, absolute.z))


func _finish_failure(message: String) -> void:
	_report["outcome"] = "fail"
	_report["proof_passed"] = false
	_report["failure_reason"] = message
	_write_report()
	push_error("FORGE_V2_NATIVE_MANIFOLD_UNION_VERIFY: %s" % message)
	quit(1)


func _write_report() -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report, "\t"))
