extends RefCounted

## Read-only saved Forge V2 profiles, extruded by the existing Forge preview mesher.
## These fixtures replace only the captured object surface; they do not tune grip.
## Godot API references checked before implementation:
## https://docs.godotengine.org/en/stable/classes/class_resourceloader.html
## https://docs.godotengine.org/en/stable/classes/class_mesh.html#class-mesh-method-surface-get-arrays
## https://docs.godotengine.org/en/stable/classes/class_surfacetool.html
const Profiles = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const Body = preload("res://runtime/forge_v2/forge_v2_material_body.gd")
const Presenter = preload("res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd")
const SOURCE_PATH := "C:/WORKSPACE/test_artifacts/pre_grip_overhaul_backup_2026-09-18_00-43-48/external_user_saves/forge/tool_presets/player_tool_profile_library_state.tres"
const SOURCE_SHA256 := "44a66462e706cbdb3fb2d3f829f6f615f28cda0020c9fef48d5c9031cf036133"
const PROFILE_IDS := ["handle_profile_1783395703.211_3", "handle_profile_1787890891.94_10", "handle_profile_1787891232.544_14"]
const OWNER := &"linear_handle_template_proof"
const OUTLINE_FRAME_ROUNDOFF_GUARD_M := 0.0000002

func load_profile(profile_id: String) -> Dictionary:
	if not PROFILE_IDS.has(profile_id): return _failure("profile_not_in_requested_three")
	if FileAccess.get_sha256(SOURCE_PATH) != SOURCE_SHA256: return _failure("saved_profile_library_hash_mismatch")
	var library: Resource = ResourceLoader.load(SOURCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if library == null or not library.has_method("get_saved_profile"): return _failure("saved_profile_library_unavailable")
	var source: Dictionary = library.call("get_saved_profile", StringName(profile_id))
	if source.is_empty() or source.get("family") != Profiles.PROFILE_FAMILY_HANDLE:
		return _failure("saved_handle_profile_missing")
	# Require the actual saved outline; never silently reconstruct from controls.
	if not source.get("base_polygon_2d_meters") is PackedVector2Array:
		return _failure("saved_base_outline_missing")
	var base: PackedVector2Array = source.base_polygon_2d_meters
	if base.size() < 3: return _failure("saved_base_outline_too_small")
	for point: Vector2 in base:
		if not point.is_finite(): return _failure("nonfinite_saved_profile")
	var compiled: Dictionary = Profiles.compile_handle_profile_runtime_data(source)
	var runtime: Dictionary = compiled.get("compiled_profile", {})
	if not runtime.get("valid", false): return _failure("saved_profile_compilation_failed", runtime)
	if compiled.base_polygon_2d_meters != base: return _failure("compiler_changed_saved_outline")
	var polygon: PackedVector2Array = runtime.deposition_polygon_2d_meters
	var minimum: Vector2 = polygon[0]
	var maximum: Vector2 = polygon[0]
	for point: Vector2 in polygon:
		minimum = minimum.min(point); maximum = maximum.max(point)
	var size: Vector2 = maximum - minimum
	var metadata := {
		"schema": "linear_saved_handle_fixture_v1", "profile_id": profile_id,
		"profile_label": String(source.get("label", profile_id)),
		"source_path": SOURCE_PATH, "source_sha256": SOURCE_SHA256,
		"profile_size_m": [size.x, size.y],
		"authoring_size_m": [float(source.get("width_meters", 0.0)), float(source.get("height_meters", 0.0))],
		"profile_polygon_m": _points(polygon), "saved_base_polygon_m": _points(base),
		"profile_anchor_m": _point(runtime.anchor_2d_meters),
		"profile_rotation_degrees": float(compiled.get("rotation_degrees", 0.0)),
		"profile_vertex_count": polygon.size(), "profile_scale_multiplier": 1.0,
		"profile_contact_direction": _point(runtime.contact_direction_2d),
		"profile_contact_distance_m": float(runtime.contact_distance_meters),
		"compiler": "ForgeV2ProfileShapeLibrary.compile_handle_profile_runtime_data",
		"extruder": "ForgeV2VolumePreviewPresenter._build_active_material_body_sweep_mesh",
		"path_kind": "straight_two_point_profile_path", "twist_degrees_per_meter": 0.0,
		"source_library_written": false, "grip_parameters_changed": false}
	return {"valid": true, "profile": compiled, "runtime": runtime, "metadata": metadata}

func build_for_stage(fixture: Dictionary, stage: Dictionary) -> Dictionary:
	if not fixture.get("valid", false): return _failure("invalid_profile_fixture")
	if not stage.get("object") is Dictionary or not stage.get("posed_character") is Dictionary:
		return _failure("missing_captured_stage")
	var captured: Dictionary = stage.object
	if not captured.get("weapon_origin_record") is Dictionary or not captured.get("weapon_to_world") is Transform3D:
		return _failure("missing_captured_weapon_frame")
	if not captured.get("primary_grip_span_start_local") is Vector3 or not captured.get("primary_grip_span_end_local") is Vector3:
		return _failure("missing_captured_handle_span")
	var weapon_id: StringName = captured.weapon_origin_record.origin_id
	for endpoint: String in ["start", "end"]:
		if captured.get("primary_grip_span_" + endpoint + "_origin_id") != weapon_id:
			return _failure("captured_handle_span_origin_mismatch")
	var start: Vector3 = captured.primary_grip_span_start_local
	var end: Vector3 = captured.primary_grip_span_end_local
	var span_length: float = start.distance_to(end)
	if not start.is_finite() or not end.is_finite() or span_length <= 0.000001:
		return _failure("invalid_captured_handle_span")
	var weapon_to_world: Transform3D = captured.weapon_to_world
	if not weapon_to_world.is_finite() or not _rigid_basis(weapon_to_world.basis):
		return _failure("captured_weapon_frame_would_scale_profile")
	var runtime: Dictionary = fixture.runtime
	var profile: Dictionary = fixture.profile
	var polygon: PackedVector2Array = runtime.deposition_polygon_2d_meters
	var tangent: Vector3 = (end - start).normalized()
	# Forge's default deposition reference, made explicit and recorded here.
	# Roll remains the authored profile rotation, without pose-specific adjustment.
	var surface_normal := Vector3.FORWARD
	var frame: Dictionary = Profiles.resolve_profile_path_frame(tangent, surface_normal,
		runtime.contact_direction_2d, float(profile.get("rotation_degrees", 0.0)))
	var profile_to_weapon := Transform3D(Basis(frame.axis_x, frame.axis_y, frame.tangent), (start + end) * 0.5)
	if not profile_to_weapon.is_finite() or not _rigid_basis(profile_to_weapon.basis):
		return _failure("invalid_compiled_profile_frame")
	var body: Resource = Body.new()
	body.body_kind = Body.BODY_KIND_HANDLE_PROFILE
	body.shape_kind = Body.SHAPE_KIND_PROFILE_PATH
	body.profile_role = Body.PROFILE_ROLE_HANDLE
	body.profile_id = StringName(fixture.metadata.profile_id)
	body.profile_display_name = fixture.metadata.profile_label
	body.path_points = PackedVector3Array([start, end])
	body.path_surface_normals = PackedVector3Array([surface_normal, surface_normal])
	body.profile_polygon_2d_meters = polygon
	body.profile_anchor_2d_meters = runtime.anchor_2d_meters
	body.profile_contact_point_relative_2d_meters = runtime.contact_point_relative_2d_meters
	body.profile_contact_direction_2d = runtime.contact_direction_2d
	body.profile_contact_distance_meters = runtime.contact_distance_meters
	body.profile_runtime_schema_version = runtime.schema_version
	body.profile_rotation_bias_degrees = float(profile.get("rotation_degrees", 0.0))
	body.profile_twist_degrees_per_meter = 0.0
	body.radius_meters = Profiles.calculate_polygon_max_radius_meters(polygon)
	var presenter: Node = Presenter.new()
	var mesh: ArrayMesh = presenter.call("_build_active_material_body_sweep_mesh", body) as ArrayMesh
	presenter.free()
	if mesh == null or mesh.get_surface_count() != 1: return _failure("forge_linear_extrusion_failed")
	# Mesh.get_faces() routes through TriangleMesh and snaps positions to 0.1 mm.
	# Keep the actual Forge-rendered vertex/index arrays instead of that BVH copy.
	var extracted: Dictionary = _unaltered_mesh_faces(mesh)
	if not extracted.get("valid", false): return extracted
	var faces: PackedVector3Array = profile_to_weapon.affine_inverse() * (extracted.faces as PackedVector3Array)
	var outline_check: Dictionary = _check_extruded_outline(faces, polygon, span_length)
	if not outline_check.get("valid", false): return outline_check
	var topology := _check_closed_faces(faces)
	if not topology.get("valid", false): return topology
	var profile_id: StringName = StringName("ProofLinearHandleProfileOrigin_" + String(fixture.metadata.profile_id).replace(".", "_") + "_" + String(stage.get("slot", "unknown")))
	var record := {"origin_id": profile_id, "parent_origin_id": weapon_id,
		"transform_to_parent": profile_to_weapon, "owner_system": OWNER,
		"resolve_phase": stage.posed_character.resolve_phase, "is_dynamic": false, "space_type": &"presentation"}
	var replacement: Dictionary = captured.duplicate(true)
	for field: String in ["mesh_instance_id", "mesh_resource_id", "visual_mesh_source", "geometry_policy"]:
		if replacement.has(field):
			replacement["captured_source_" + field] = replacement[field]
			replacement.erase(field)
	replacement["visual_mesh_source"] = &"saved_forge_v2_profile_linear_sweep_fixture"
	replacement["geometry_policy"] = &"unaltered_surface_vertex_index_arrays_no_bvh"
	# These identify the generated sweep triangles, not triangles from the
	# captured weapon whose pose/span supplied the fixture placement.
	replacement["local_face_sources"] = extracted.local_face_sources
	replacement["source_surface_count"] = mesh.get_surface_count()
	replacement["triangle_source_geometry"] = &"generated_forge_profile_sweep_surface_arrays"
	replacement["origin_record"] = record
	replacement["local_faces_origin_id"] = profile_id
	replacement["local_faces"] = faces
	replacement["mesh_to_world"] = weapon_to_world * profile_to_weapon
	var output_stage: Dictionary = stage.duplicate(true)
	output_stage["object"] = replacement
	var metadata: Dictionary = fixture.metadata.duplicate(true)
	metadata.merge({"profile_origin_id": profile_id, "profile_origin_record": record,
		"weapon_origin_id": weapon_id, "length_m": span_length,
		"length_policy": "preserve_captured_grip_span_length", "datum_policy": "captured_span_midpoint",
		"span_start_weapon_m": start, "span_end_weapon_m": end,
		"deposition_surface_normal_weapon": surface_normal, "deposition_vectors_origin_id": weapon_id,
		"profile_to_weapon": profile_to_weapon, "mesh_to_world": replacement.mesh_to_world,
		"triangle_count": faces.size() / 3, "surface_count": mesh.get_surface_count(),
		"triangle_provenance": "generated_sweep_surface_triangle_and_original_vertex_indices",
		"mesh_extraction": "surface_vertex_index_arrays_without_TriangleMesh_snapping",
		"outline_equality": outline_check,
		"closed_edge_incidence_verified": true, "local_faces_sha256": _sha256(var_to_bytes(faces)),
		"local_faces_origin_id": profile_id, "captured_pose_unchanged": output_stage.posed_character == stage.posed_character}, true)
	return {"valid": true, "stage": output_stage, "metadata": metadata}

func _unaltered_mesh_faces(mesh: ArrayMesh) -> Dictionary:
	if mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
		return _failure("forge_surface_not_triangles")
	var arrays: Array = mesh.surface_get_arrays(0)
	if arrays.size() != Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
		return _failure("forge_surface_arrays_missing")
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
	if indices.is_empty():
		return {"valid": true, "faces": vertices.duplicate(),
			"local_face_sources": _triangle_sources(indices, vertices.size())}
	if indices.size() % 3 != 0: return _failure("forge_triangle_indices_incomplete")
	var faces := PackedVector3Array()
	faces.resize(indices.size())
	for index: int in indices.size():
		if indices[index] < 0 or indices[index] >= vertices.size():
			return _failure("forge_triangle_index_out_of_bounds")
		faces[index] = vertices[indices[index]]
	return {"valid": true, "faces": faces,
		"local_face_sources": _triangle_sources(indices, faces.size())}

func _triangle_sources(indices: PackedInt32Array, face_vertex_count: int) -> Array:
	var sources: Array = []
	var indexed: bool = not indices.is_empty()
	for start: int in range(0, face_vertex_count, 3):
		var vertices := PackedInt32Array()
		for corner: int in range(3):
			vertices.append(indices[start + corner] if indexed else start + corner)
		sources.append({"surface_index": 0, "triangle_index": start / 3,
			"vertex_indices": vertices, "indexed": indexed})
	return sources

func _check_extruded_outline(faces: PackedVector3Array, polygon: PackedVector2Array, length_m: float) -> Dictionary:
	var seen := {}
	var maximum_xy_error_m: float = 0.0
	var maximum_axial_error_m: float = 0.0
	for vertex: Vector3 in faces:
		var axial_error: float = absf(absf(vertex.z) - length_m * 0.5)
		var nearest: float = INF
		var nearest_index: int = -1
		for index: int in polygon.size():
			var distance: float = Vector2(vertex.x, vertex.y).distance_to(polygon[index])
			if distance < nearest: nearest = distance; nearest_index = index
		maximum_xy_error_m = maxf(maximum_xy_error_m, nearest)
		maximum_axial_error_m = maxf(maximum_axial_error_m, axial_error)
		if nearest > OUTLINE_FRAME_ROUNDOFF_GUARD_M or axial_error > OUTLINE_FRAME_ROUNDOFF_GUARD_M:
			return _failure("forge_extracted_surface_changed_saved_outline", {"profile_xy_error_m": nearest, "axial_error_m": axial_error, "guard_m": OUTLINE_FRAME_ROUNDOFF_GUARD_M})
		seen[Vector2i(nearest_index, 1 if vertex.z > 0.0 else -1)] = true
	if seen.size() != polygon.size() * 2: return _failure("forge_extracted_surface_omits_profile_ring_vertex")
	return {"valid": true, "guard_m": OUTLINE_FRAME_ROUNDOFF_GUARD_M,
		"maximum_xy_error_m": maximum_xy_error_m, "maximum_axial_error_m": maximum_axial_error_m,
		"complete_profile_rings": true, "exact_infinite_precision_claim": false}

func _check_closed_faces(faces: PackedVector3Array) -> Dictionary:
	if faces.is_empty() or faces.size() % 3 != 0: return _failure("invalid_forge_triangle_array")
	var vertex_ids := {}
	var edge_counts := {}
	var edge_balance := {}
	for offset: int in range(0, faces.size(), 3):
		var ids: Array[int] = []
		for index: int in range(3):
			var vertex: Vector3 = faces[offset + index]
			if not vertex.is_finite(): return _failure("nonfinite_forge_vertex")
			if not vertex_ids.has(vertex): vertex_ids[vertex] = vertex_ids.size()
			ids.append(vertex_ids[vertex])
		if (faces[offset + 1] - faces[offset]).cross(faces[offset + 2] - faces[offset]).length_squared() < 1e-24:
			return _failure("degenerate_forge_triangle")
		for index: int in range(3):
			var a: int = ids[index]
			var b: int = ids[(index + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			edge_counts[key] = int(edge_counts.get(key, 0)) + 1
			edge_balance[key] = int(edge_balance.get(key, 0)) + (1 if a < b else -1)
	for key: Vector2i in edge_counts:
		if edge_counts[key] != 2 or edge_balance[key] != 0:
			return _failure("forge_surface_not_closed_or_consistently_wound", {"edge": key, "count": edge_counts[key], "balance": edge_balance[key]})
	return {"valid": true}

func _rigid_basis(value: Basis) -> bool:
	return value.is_finite() and absf(value.determinant() - 1.0) < 0.0001 and value.is_equal_approx(value.orthonormalized())

func _points(polygon: PackedVector2Array) -> Array:
	var result: Array = []
	for point: Vector2 in polygon: result.append(_point(point))
	return result

func _point(value: Vector2) -> Array:
	return [value.x, value.y]

func _sha256(bytes: PackedByteArray) -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256); digest.update(bytes)
	return digest.finish().hex_encode()

func _failure(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"valid": false, "reason": reason, "details": details}
