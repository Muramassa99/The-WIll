extends SceneTree

const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeV2VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)
const MeshAnalyzerScript = preload(
	"res://tools/forge_v2_workpiece_benchmark_mesh_analyzer.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_builtin_csg_cap_sentinel_2026-08-15_run3.json"
)
const SENTINEL_MATERIAL_NAME := (
	"__forge_v2_compiler_cap_sentinel_2026_08_15_run3__"
)
const ORGANIC_MATERIAL_NAME := (
	"forge_v2_builtin_cap_sentinel_organic_fixture"
)
const CHUNK_SIZE_METERS := 0.064
const SHARED_PLANE_X_METERS := 0.0
const PLANE_TOLERANCE_METERS := 0.00002
const SEAM_QUANTIZATION_METERS := 0.0000001
const AABB_TOLERANCE_METERS := 0.00001
const VOLUME_RELATIVE_TOLERANCE := 0.0001
const VOLUME_ABSOLUTE_FLOOR_CUBIC_METERS := 0.0000000005
const SURFACE_DISTANCE_TOLERANCE_METERS := 0.00002
const NORMAL_DOT_TOLERANCE := 0.999
const STABLE_BAKE_MAX_FRAMES := 40

var report: Dictionary = {
	"verifier_id": "forge_v2_builtin_csg_cap_sentinel_v1",
	"verifier_schema": 1,
	"ok": false,
	"production_ready": false,
	"backend_scope": "tools_only_builtin_godot_csg_feasibility_scaffold",
	"native_status": "unavailable_builtin_csg",
	"meshgl64": "unavailable_builtin_csg",
	"original_id": "unavailable_builtin_csg",
	"face_id": "unavailable_builtin_csg",
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var presenter: Node3D = ForgeV2VolumePreviewPresenterScript.new()
	presenter.name = "BuiltinCapSentinelFixturePresenter"
	root.add_child(presenter)
	await process_frame

	var body := _build_oblique_fixture_body()
	var exact_mesh: ArrayMesh = presenter.call(
		"_build_active_material_body_sweep_mesh",
		body
	) as ArrayMesh
	if exact_mesh == null or exact_mesh.get_surface_count() <= 0:
		_finish(false, "exact_forge_sweep_missing")
		return
	var organic_material := _build_material(
		ORGANIC_MATERIAL_NAME,
		Color(0.19, 0.61, 0.83, 1.0)
	)
	var sentinel_material := _build_material(
		SENTINEL_MATERIAL_NAME,
		Color(0.937, 0.071, 0.619, 1.0)
	)
	for surface_index in range(exact_mesh.get_surface_count()):
		exact_mesh.surface_set_material(surface_index, organic_material)

	var exact_bounds := exact_mesh.get_aabb()
	report["fixture"] = {
		"chunk_size_meters": CHUNK_SIZE_METERS,
		"shared_plane_x_meters": SHARED_PLANE_X_METERS,
		"path_sample_count": (body.get("path_points") as PackedVector3Array).size(),
		"profile_vertex_count": (
			body.get("profile_polygon_2d_meters") as PackedVector2Array
		).size(),
		"exact_aabb_position": _vector3_record(exact_bounds.position),
		"exact_aabb_size": _vector3_record(exact_bounds.size),
	}
	if not _bounds_fit_two_chunks(exact_bounds):
		_finish(false, "fixture_does_not_fit_two_adjacent_chunks")
		return

	var exact_analysis: Dictionary = MeshAnalyzerScript.analyze_mesh(exact_mesh)
	report["exact_sweep"] = MeshAnalyzerScript.strip_transient_arrays(
		exact_analysis
	)
	if not _strict_single_solid_pass(exact_analysis):
		_finish(false, "exact_forge_sweep_failed_strict_topology")
		return

	var left: Dictionary = await _bake_chunk_intersection(
		"LeftChunk",
		exact_mesh,
		organic_material,
		sentinel_material,
		Vector3(-CHUNK_SIZE_METERS * 0.5, 0.0, 0.0)
	)
	var right: Dictionary = await _bake_chunk_intersection(
		"RightChunk",
		exact_mesh,
		organic_material,
		sentinel_material,
		Vector3(CHUNK_SIZE_METERS * 0.5, 0.0, 0.0)
	)
	if not bool(left.get("ok", false)) or not bool(right.get("ok", false)):
		report["left_bake"] = _without_meshes(left)
		report["right_bake"] = _without_meshes(right)
		_finish(false, "chunk_intersection_bake_failed")
		return

	var left_mesh := left.get("mesh", null) as ArrayMesh
	var right_mesh := right.get("mesh", null) as ArrayMesh
	var left_inspection := _inspect_material_provenance(
		left_mesh,
		organic_material,
		sentinel_material
	)
	var right_inspection := _inspect_material_provenance(
		right_mesh,
		organic_material,
		sentinel_material
	)
	report["left_half"] = _serializable_inspection(left_inspection)
	report["right_half"] = _serializable_inspection(right_inspection)

	# This is the decisive Stage-1 question. Do not recover by geometrically
	# relabelling faces when Godot does not preserve the clipping-box material.
	var sentinel_provenance_pass := (
		_sentinel_provenance_pass(left_inspection)
		and _sentinel_provenance_pass(right_inspection)
	)
	report["sentinel_provenance_pass"] = sentinel_provenance_pass
	if not sentinel_provenance_pass:
		_finish(false, "sentinel_provenance_failed")
		return

	var left_cap_triangles: Array = left_inspection.get(
		"sentinel_triangles",
		[]
	) as Array
	var right_cap_triangles: Array = right_inspection.get(
		"sentinel_triangles",
		[]
	) as Array
	var left_seam := _analyze_cap_seam(left_cap_triangles)
	var right_seam := _analyze_cap_seam(right_cap_triangles)
	var boundary_signature_matches := (
		String(left_seam.get("unoriented_boundary_signature", ""))
		== String(right_seam.get("unoriented_boundary_signature", ""))
	)
	var opposite_winding := (
		(left_seam.get("area_normal", Vector3.ZERO) as Vector3).dot(
			right_seam.get("area_normal", Vector3.ZERO) as Vector3
		) <= -NORMAL_DOT_TOLERANCE
	)
	var seam_pass := (
		bool(left_seam.get("valid_loop_topology", false))
		and bool(right_seam.get("valid_loop_topology", false))
		and int(left_seam.get("loop_count", 0)) == 1
		and int(right_seam.get("loop_count", 0)) == 1
		and boundary_signature_matches
		and opposite_winding
	)
	report["paired_seam"] = {
		"pass": seam_pass,
		"boundary_signature_matches": boundary_signature_matches,
		"opposite_winding": opposite_winding,
		"left": _serializable_seam(left_seam),
		"right": _serializable_seam(right_seam),
	}
	if not seam_pass:
		_finish(false, "paired_cap_seam_failed")
		return

	var left_organic := left_inspection.get("organic_mesh", null) as ArrayMesh
	var right_organic := right_inspection.get("organic_mesh", null) as ArrayMesh
	if left_organic == null or right_organic == null:
		_finish(false, "organic_half_extraction_failed")
		return
	var organic_halves: Array[ArrayMesh] = [left_organic, right_organic]
	var reconstructed_analysis: Dictionary = MeshAnalyzerScript.analyze_meshes(
		organic_halves
	)
	var surface_comparison: Dictionary = MeshAnalyzerScript.compare_surfaces(
		reconstructed_analysis,
		exact_analysis
	)
	var aabb_delta := _calculate_aabb_max_delta(
		reconstructed_analysis,
		exact_analysis
	)
	var exact_volume := float(exact_analysis.get(
		"absolute_volume_cubic_meters",
		0.0
	))
	var reconstructed_volume := float(reconstructed_analysis.get(
		"absolute_volume_cubic_meters",
		0.0
	))
	var volume_absolute_delta := absf(reconstructed_volume - exact_volume)
	var volume_relative_delta := (
		volume_absolute_delta / exact_volume
		if exact_volume > 0.000000000001
		else INF
	)
	var volume_allowance := maxf(
		VOLUME_ABSOLUTE_FLOOR_CUBIC_METERS,
		exact_volume * VOLUME_RELATIVE_TOLERANCE
	)
	var surface_distance := float(surface_comparison.get(
		"bidirectional_max_meters",
		INF
	))
	var reconstruction_pass := (
		_strict_single_solid_pass(reconstructed_analysis)
		and aabb_delta <= AABB_TOLERANCE_METERS
		and volume_absolute_delta <= volume_allowance
		and volume_relative_delta <= VOLUME_RELATIVE_TOLERANCE
		and surface_distance <= SURFACE_DISTANCE_TOLERANCE_METERS
		and float(reconstructed_analysis.get("signed_volume_sign", 0.0))
		== float(exact_analysis.get("signed_volume_sign", 0.0))
	)
	report["organic_reconstruction"] = {
		"pass": reconstruction_pass,
		"analysis": MeshAnalyzerScript.strip_transient_arrays(
			reconstructed_analysis
		),
		"aabb_max_delta_meters": aabb_delta,
		"aabb_tolerance_meters": AABB_TOLERANCE_METERS,
		"volume_absolute_delta_cubic_meters": volume_absolute_delta,
		"volume_relative_delta": volume_relative_delta,
		"volume_absolute_allowance_cubic_meters": volume_allowance,
		"volume_relative_tolerance": VOLUME_RELATIVE_TOLERANCE,
		"surface_comparison": surface_comparison,
		"surface_distance_tolerance_meters": (
			SURFACE_DISTANCE_TOLERANCE_METERS
		),
	}
	if not reconstruction_pass:
		_finish(false, "organic_half_reconstruction_failed")
		return

	report["steady_live_csg_node_count"] = _count_csg_nodes(root)
	report["sentinel_provenance_pass"] = true
	report["paired_seam_pass"] = true
	report["organic_reconstruction_pass"] = true
	_finish(true, "")


func _build_oblique_fixture_body() -> Resource:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var contacts := PackedVector3Array()
	for point_index in range(9):
		var u := float(point_index) / 8.0
		var centered := u * 2.0 - 1.0
		points.append(Vector3(
			-0.043 + 0.086 * u,
			-0.006 + 0.012 * u + 0.0025 * sin(TAU * u),
			-0.004 + 0.009 * u + 0.0020 * sin(PI * u)
		))
		var normal := Vector3(
			0.37 + 0.06 * sin(1.3 * PI * centered),
			0.49 + 0.05 * cos(1.7 * PI * centered),
			0.71 + 0.04 * sin(0.9 * PI * centered)
		).normalized()
		normals.append(normal)
		contacts.append(-normal)
	var polygon := PackedVector2Array()
	for profile_index in range(17):
		var angle := TAU * float(profile_index) / 17.0
		var radius_scale := (
			1.0
			+ 0.11 * sin(angle)
			+ 0.06 * cos(2.0 * angle)
			+ 0.025 * sin(5.0 * angle)
		)
		polygon.append(Vector2(
			0.009 * radius_scale * cos(angle) + 0.0006 * sin(3.0 * angle),
			0.011 * (1.0 + 0.07 * cos(angle)) * sin(angle)
		))
	var body: Resource = ForgeV2MaterialBodyScript.new()
	body.set("body_id", &"builtin_cap_sentinel_oblique_sweep")
	body.set("source_record_id", &"builtin_cap_sentinel_oblique_source")
	body.set("body_kind", ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE)
	body.set("shape_kind", ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH)
	body.set("material_variant_id", &"mat_iron_gray")
	body.set("path_points", points)
	body.set("path_surface_normals", normals)
	body.set("path_contact_directions", contacts)
	body.set("profile_id", &"builtin_cap_sentinel_asymmetric_profile")
	body.set("profile_display_name", "Builtin Cap Sentinel Asymmetric Profile")
	body.set("profile_polygon_2d_meters", polygon)
	body.set("profile_anchor_2d_meters", Vector2.ZERO)
	body.set("profile_contact_point_relative_2d_meters", Vector2(0.0, -0.010))
	body.set(
		"profile_contact_direction_2d",
		ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
	)
	body.set("profile_contact_distance_meters", 0.010)
	body.set("profile_runtime_schema_version", 1)
	body.set("profile_rotation_bias_degrees", 13.0)
	body.call("normalize")
	body.set("body_id", &"builtin_cap_sentinel_oblique_sweep")
	body.set("source_record_id", &"builtin_cap_sentinel_oblique_source")
	return body


func _build_material(resource_name: String, color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = resource_name
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _bounds_fit_two_chunks(bounds: AABB) -> bool:
	var minimum := bounds.position
	var maximum := bounds.end
	var half_chunk := CHUNK_SIZE_METERS * 0.5
	return (
		minimum.x > -CHUNK_SIZE_METERS + PLANE_TOLERANCE_METERS
		and maximum.x < CHUNK_SIZE_METERS - PLANE_TOLERANCE_METERS
		and minimum.x < -0.005
		and maximum.x > 0.005
		and minimum.y > -half_chunk + PLANE_TOLERANCE_METERS
		and maximum.y < half_chunk - PLANE_TOLERANCE_METERS
		and minimum.z > -half_chunk + PLANE_TOLERANCE_METERS
		and maximum.z < half_chunk - PLANE_TOLERANCE_METERS
	)


func _bake_chunk_intersection(
	label: String,
	exact_mesh: ArrayMesh,
	organic_material: Material,
	sentinel_material: Material,
	chunk_center: Vector3
) -> Dictionary:
	var combiner := CSGCombiner3D.new()
	combiner.name = "%sIntersection" % label
	combiner.calculate_tangents = false
	root.add_child(combiner)
	var sweep := CSGMesh3D.new()
	sweep.name = "%sExactSweep" % label
	sweep.operation = CSGShape3D.OPERATION_UNION
	sweep.calculate_tangents = false
	sweep.mesh = exact_mesh
	sweep.material = organic_material
	combiner.add_child(sweep)
	var clip_box := CSGBox3D.new()
	clip_box.name = "%sSentinelClipBox" % label
	clip_box.operation = CSGShape3D.OPERATION_INTERSECTION
	clip_box.calculate_tangents = false
	clip_box.size = Vector3.ONE * CHUNK_SIZE_METERS
	clip_box.position = chunk_center
	clip_box.material = sentinel_material
	combiner.add_child(clip_box)

	var baked_mesh: ArrayMesh = null
	var previous_signature := ""
	var stable_frame_count := 0
	var waited_frames := 0
	for frame_index in range(STABLE_BAKE_MAX_FRAMES):
		await process_frame
		waited_frames = frame_index + 1
		var candidate := combiner.bake_static_mesh()
		if candidate == null or candidate.get_surface_count() <= 0:
			continue
		var signature := _quick_mesh_signature(candidate)
		if signature == previous_signature and not signature.is_empty():
			stable_frame_count += 1
		else:
			stable_frame_count = 1
		previous_signature = signature
		baked_mesh = candidate
		if stable_frame_count >= 2:
			break
	var result := {
		"ok": baked_mesh != null and stable_frame_count >= 2,
		"mesh": baked_mesh,
		"stable_frame_count": stable_frame_count,
		"waited_frames": waited_frames,
		"geometry_signature": previous_signature,
	}
	root.remove_child(combiner)
	combiner.free()
	await process_frame
	return result


func _quick_mesh_signature(mesh: ArrayMesh) -> String:
	if mesh == null:
		return ""
	var parts := PackedStringArray(["surfaces=%d" % mesh.get_surface_count()])
	for surface_index in range(mesh.get_surface_count()):
		var material := mesh.surface_get_material(surface_index)
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		parts.append("M:%s" % _material_identity(material))
		parts.append("V:%d:I:%d" % [vertices.size(), indices.size()])
		for vertex: Vector3 in vertices:
			parts.append(_vector3_quantized_key(vertex, SEAM_QUANTIZATION_METERS))
		for index: int in indices:
			parts.append(str(index))
	return "\n".join(parts).sha256_text()


func _inspect_material_provenance(
	mesh: ArrayMesh,
	organic_material: Material,
	sentinel_material: Material
) -> Dictionary:
	var sentinel_triangles: Array[PackedVector3Array] = []
	var organic_surface_indices := PackedInt32Array()
	var sentinel_triangle_count := 0
	var organic_triangle_count := 0
	var unknown_triangle_count := 0
	var sentinel_off_plane_triangle_count := 0
	var organic_on_plane_triangle_count := 0
	var degenerate_triangle_count := 0
	var nonfinite_triangle_count := 0
	var surface_materials: Array[Dictionary] = []
	if mesh == null:
		return {
			"mesh_missing": true,
			"sentinel_triangles": sentinel_triangles,
		}
	for surface_index in range(mesh.get_surface_count()):
		var material := mesh.surface_get_material(surface_index)
		var is_sentinel := _material_matches(material, sentinel_material)
		var is_organic := _material_matches(material, organic_material)
		var material_class := "sentinel" if is_sentinel else (
			"organic" if is_organic else "unknown"
		)
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var source_count := indices.size() if not indices.is_empty() else vertices.size()
		var surface_triangle_count := 0
		for triangle_offset in range(0, source_count - 2, 3):
			var triangle := PackedVector3Array()
			for corner_offset in range(3):
				var source_index := (
					indices[triangle_offset + corner_offset]
					if not indices.is_empty()
					else triangle_offset + corner_offset
				)
				if source_index < 0 or source_index >= vertices.size():
					continue
				triangle.append(vertices[source_index])
			if triangle.size() != 3:
				degenerate_triangle_count += 1
				continue
			surface_triangle_count += 1
			if (
				not triangle[0].is_finite()
				or not triangle[1].is_finite()
				or not triangle[2].is_finite()
			):
				nonfinite_triangle_count += 1
				continue
			if (
				(triangle[1] - triangle[0]).cross(
					triangle[2] - triangle[0]
				).length_squared() <= 0.0000000000000001
			):
				degenerate_triangle_count += 1
				continue
			var on_shared_plane := _triangle_is_on_shared_plane(triangle)
			if is_sentinel:
				sentinel_triangle_count += 1
				sentinel_triangles.append(triangle)
				if not on_shared_plane:
					sentinel_off_plane_triangle_count += 1
			elif is_organic:
				organic_triangle_count += 1
				if on_shared_plane:
					organic_on_plane_triangle_count += 1
			else:
				unknown_triangle_count += 1
		surface_materials.append({
			"surface_index": surface_index,
			"material_identity": _material_identity(material),
			"material_class": material_class,
			"triangle_count": surface_triangle_count,
		})
		if is_organic:
			organic_surface_indices.append(surface_index)
	var organic_mesh := _copy_selected_surfaces(mesh, organic_surface_indices)
	return {
		"mesh_missing": false,
		"surface_materials": surface_materials,
		"sentinel_triangle_count": sentinel_triangle_count,
		"organic_triangle_count": organic_triangle_count,
		"unknown_triangle_count": unknown_triangle_count,
		"sentinel_off_plane_triangle_count": (
			sentinel_off_plane_triangle_count
		),
		"organic_on_plane_triangle_count": organic_on_plane_triangle_count,
		"degenerate_triangle_count": degenerate_triangle_count,
		"nonfinite_triangle_count": nonfinite_triangle_count,
		"sentinel_triangles": sentinel_triangles,
		"organic_mesh": organic_mesh,
	}


func _sentinel_provenance_pass(inspection: Dictionary) -> bool:
	return (
		not bool(inspection.get("mesh_missing", true))
		and int(inspection.get("sentinel_triangle_count", 0)) > 0
		and int(inspection.get("organic_triangle_count", 0)) > 0
		and int(inspection.get("unknown_triangle_count", 0)) == 0
		and int(inspection.get("sentinel_off_plane_triangle_count", 0)) == 0
		and int(inspection.get("organic_on_plane_triangle_count", 0)) == 0
		and int(inspection.get("nonfinite_triangle_count", 0)) == 0
		and inspection.get("organic_mesh", null) is ArrayMesh
	)


func _triangle_is_on_shared_plane(triangle: PackedVector3Array) -> bool:
	if triangle.size() != 3:
		return false
	for point: Vector3 in triangle:
		if absf(point.x - SHARED_PLANE_X_METERS) > PLANE_TOLERANCE_METERS:
			return false
	return true


func _copy_selected_surfaces(
	mesh: ArrayMesh,
	surface_indices: PackedInt32Array
) -> ArrayMesh:
	var result := ArrayMesh.new()
	if mesh == null:
		return result
	for surface_index: int in surface_indices:
		if surface_index < 0 or surface_index >= mesh.get_surface_count():
			continue
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(
			result.get_surface_count() - 1,
			mesh.surface_get_material(surface_index)
		)
	return result


func _analyze_cap_seam(triangles: Array) -> Dictionary:
	var edge_records: Dictionary = {}
	var vertex_neighbors: Dictionary = {}
	var area_normal_sum := Vector3.ZERO
	var cap_area := 0.0
	for triangle_variant: Variant in triangles:
		if not triangle_variant is PackedVector3Array:
			continue
		var triangle := triangle_variant as PackedVector3Array
		if triangle.size() != 3:
			continue
		var cross := (triangle[1] - triangle[0]).cross(
			triangle[2] - triangle[0]
		)
		area_normal_sum += cross
		cap_area += cross.length() * 0.5
		for edge_index in range(3):
			var first_key := _projected_seam_key(triangle[edge_index])
			var second_key := _projected_seam_key(
				triangle[(edge_index + 1) % 3]
			)
			if first_key == second_key:
				continue
			var low_key := first_key if first_key < second_key else second_key
			var high_key := second_key if first_key < second_key else first_key
			var edge_key := "%s|%s" % [low_key, high_key]
			var record: Dictionary = edge_records.get(edge_key, {
				"count": 0,
				"first": first_key,
				"second": second_key,
			}) as Dictionary
			record["count"] = int(record.get("count", 0)) + 1
			edge_records[edge_key] = record
	var boundary_edges := PackedStringArray()
	for edge_key_variant: Variant in edge_records.keys():
		var edge_key := String(edge_key_variant)
		var record := edge_records[edge_key] as Dictionary
		if int(record.get("count", 0)) != 1:
			continue
		boundary_edges.append(edge_key)
		var first := String(record.get("first", ""))
		var second := String(record.get("second", ""))
		_append_string_neighbor(vertex_neighbors, first, second)
		_append_string_neighbor(vertex_neighbors, second, first)
	boundary_edges.sort()
	var degrees_are_two := not vertex_neighbors.is_empty()
	for neighbors_variant: Variant in vertex_neighbors.values():
		var neighbors := neighbors_variant as Array
		if neighbors.size() != 2:
			degrees_are_two = false
			break
	var loop_count := _count_neighbor_components(vertex_neighbors)
	return {
		"valid_loop_topology": (
			not boundary_edges.is_empty()
			and degrees_are_two
			and loop_count > 0
		),
		"loop_count": loop_count,
		"boundary_edge_count": boundary_edges.size(),
		"unoriented_boundary_signature": (
			"\n".join(boundary_edges).sha256_text()
		),
		"area_normal": area_normal_sum.normalized()
		if area_normal_sum.length_squared() > 0.0
		else Vector3.ZERO,
		"cap_area_square_meters": cap_area,
	}


func _append_string_neighbor(
	neighbors_by_vertex: Dictionary,
	vertex_key: String,
	neighbor_key: String
) -> void:
	var neighbors: Array = neighbors_by_vertex.get(vertex_key, []) as Array
	if not neighbors.has(neighbor_key):
		neighbors.append(neighbor_key)
	neighbors_by_vertex[vertex_key] = neighbors


func _count_neighbor_components(neighbors_by_vertex: Dictionary) -> int:
	var visited: Dictionary = {}
	var component_count := 0
	for vertex_key_variant: Variant in neighbors_by_vertex.keys():
		var vertex_key := String(vertex_key_variant)
		if visited.has(vertex_key):
			continue
		component_count += 1
		var pending: Array[String] = [vertex_key]
		while not pending.is_empty():
			var current := String(pending.pop_back())
			if visited.has(current):
				continue
			visited[current] = true
			var neighbors: Array = neighbors_by_vertex.get(current, []) as Array
			for neighbor_variant: Variant in neighbors:
				var neighbor := String(neighbor_variant)
				if not visited.has(neighbor):
					pending.append(neighbor)
	return component_count


func _projected_seam_key(point: Vector3) -> String:
	return "%d,%d" % [
		roundi(point.y / SEAM_QUANTIZATION_METERS),
		roundi(point.z / SEAM_QUANTIZATION_METERS),
	]


func _material_matches(material: Material, expected: Material) -> bool:
	if material == null or expected == null:
		return false
	if material == expected:
		return true
	if material.resource_name != expected.resource_name:
		return false
	if material is BaseMaterial3D and expected is BaseMaterial3D:
		return (material as BaseMaterial3D).albedo_color.is_equal_approx(
			(expected as BaseMaterial3D).albedo_color
		)
	return true


func _material_identity(material: Material) -> String:
	if material == null:
		return "<null>"
	var color_text := ""
	if material is BaseMaterial3D:
		color_text = ":%s" % str((material as BaseMaterial3D).albedo_color)
	return "%s%s" % [material.resource_name, color_text]


func _strict_single_solid_pass(analysis: Dictionary) -> bool:
	return (
		bool(analysis.get("strict_watertight", false))
		and int(analysis.get("strict_component_count", -1)) == 1
		and int(analysis.get("strict_boundary_edge_count", -1)) == 0
		and int(analysis.get("strict_nonmanifold_edge_count", -1)) == 0
		and int(analysis.get("strict_directed_edge_mismatch_count", -1)) == 0
		and int(analysis.get("strict_degenerate_triangle_collapse_count", -1)) == 0
		and int(analysis.get("degenerate_triangle_count", -1)) == 0
		and int(analysis.get("nonfinite_vertex_count", -1)) == 0
	)


func _calculate_aabb_max_delta(first: Dictionary, second: Dictionary) -> float:
	var maximum_delta := 0.0
	for field_name: String in [
		"aabb_position_x",
		"aabb_position_y",
		"aabb_position_z",
		"aabb_size_x",
		"aabb_size_y",
		"aabb_size_z",
	]:
		maximum_delta = maxf(
			maximum_delta,
			absf(float(first.get(field_name, 0.0)) - float(second.get(
				field_name,
				0.0
			)))
		)
	return maximum_delta


func _count_csg_nodes(node: Node) -> int:
	var count := 1 if node is CSGShape3D else 0
	for child: Node in node.get_children():
		count += _count_csg_nodes(child)
	return count


func _serializable_inspection(inspection: Dictionary) -> Dictionary:
	var result := inspection.duplicate(false)
	result.erase("sentinel_triangles")
	result.erase("organic_mesh")
	return result


func _serializable_seam(seam: Dictionary) -> Dictionary:
	var result := seam.duplicate(false)
	result["area_normal"] = _vector3_record(
		seam.get("area_normal", Vector3.ZERO) as Vector3
	)
	return result


func _without_meshes(value: Dictionary) -> Dictionary:
	var result := value.duplicate(false)
	result.erase("mesh")
	return result


func _vector3_record(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func _vector3_quantized_key(value: Vector3, step: float) -> String:
	return "%d,%d,%d" % [
		roundi(value.x / step),
		roundi(value.y / step),
		roundi(value.z / step),
	]


func _finish(ok: bool, error: String) -> void:
	report["ok"] = ok
	report["production_ready"] = false
	if not error.is_empty():
		report["error"] = error
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t", true) + "\n")
		file.close()
	print(
		"BUILTIN CSG CAP SENTINEL %s production_ready=false result=%s"
		% ["PASS" if ok else "FAIL", RESULT_PATH]
	)
	if not ok:
		push_error(error)
	quit(0 if ok else 1)
