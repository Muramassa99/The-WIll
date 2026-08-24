extends SceneTree

const MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const PlacementTargetResolverScript = preload(
	"res://runtime/forge_v2/forge_v2_placement_target_resolver.gd"
)
const VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)
const WorkspacePreviewScript = preload(
	"res://runtime/forge_v2/forge_v2_workspace_preview.gd"
)
const MeshAnalyzerScript = preload(
	"res://tools/forge_v2_workpiece_benchmark_mesh_analyzer.gd"
)

const EXTENSION_PATH := "res://native/forge_v2_manifold/forge_v2_manifold.gdextension"
const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/verify_forge_v2_native_manifold_live_parity.json"
)
const SURFACE_TARGET_ID := &"forge_v2_native_live_parity_surface"
const LOGICAL_BODY_ID := &"forge_v2_native_live_parity_body"
const MATERIAL_VARIANT_ID := &"mat_iron_gray"
const PROBE_LABELS := ["A", "B", "C"]
const SURFACE_DISTANCE_LIMIT_METERS := 0.00002
const BOUNDS_LIMIT_METERS := 0.00001
const HIT_POSITION_LIMIT_METERS := 0.00020
const NORMAL_DOT_MIN := 0.995
const ABC_DOT_MAX := -0.999
const DIRECT_RAY_OFFSET_METERS := 0.004
const CAMERA_DISTANCE_METERS := 0.30

var _workspace: Node3D
var _publication_body: StaticBody3D
var _report := {
	"schema": "forge_v2_native_manifold_live_parity",
	"schema_version": 1,
	"ok": false,
	"production_files_touched": false,
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	_workspace = WorkspacePreviewScript.new()
	_workspace.name = "NativeManifoldLiveParityWorkspace"
	root.add_child(_workspace)
	await process_frame
	var presenter := _workspace.get("volume_preview_presenter") as Node3D
	if presenter == null:
		presenter = VolumePreviewPresenterScript.new()
		_workspace.add_child(presenter)

	var bodies := _build_connected_explicit_bodies()
	var sweep_meshes: Array[ArrayMesh] = []
	var packets: Array[Dictionary] = []
	for body_variant: Variant in bodies:
		var body := body_variant as Resource
		if body == null or not bool(body.call("uses_explicit_surface_contact_authority")):
			_finish_failure("explicit surface body construction failed")
			return
		var sweep := presenter.call(
			"_build_active_material_body_sweep_mesh", body
		) as ArrayMesh
		var packet := _mesh_packet(sweep)
		if not bool(packet.get("ok", false)):
			_finish_failure("real presenter returned an invalid exact sweep packet")
			return
		sweep_meshes.append(sweep)
		packets.append(packet)

	var extension_resource: Resource = load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(&"ForgeV2ManifoldBoolean"):
		_finish_failure("stateful native GDExtension is unavailable")
		return
	var backend := ClassDB.instantiate(&"ForgeV2ManifoldBoolean") as Object
	if backend == null:
		_finish_failure("ForgeV2ManifoldBoolean could not be instantiated")
		return
	for method_name: StringName in [
		&"clear_state", &"reset_mesh", &"add_mesh", &"get_state_info"
	]:
		if not backend.has_method(method_name):
			_finish_failure("stateful method %s is missing" % String(method_name))
			return

	var clear_result := backend.call("clear_state") as Dictionary
	if not bool(clear_result.get("ok", false)):
		_finish_failure("native clear_state failed")
		return
	var native_steps: Array[Dictionary] = []
	var final_native_result := {}
	for packet_index in range(packets.size()):
		var packet := packets[packet_index]
		var native_result := backend.call(
			"reset_mesh" if packet_index == 0 else "add_mesh",
			packet.get("vertices", PackedVector3Array()),
			packet.get("indices", PackedInt32Array())
		) as Dictionary
		if (
			not bool(native_result.get("ok", false))
			or not bool(native_result.get("committed", false))
			or String(native_result.get("status", "")) != "NoError"
		):
			_finish_failure("native state mutation %d failed: %s" % [
				packet_index,
				String(native_result.get("error_message", "unknown")),
			])
			return
		if packet_index > 0 and not bool(native_result.get("cached_base_reused", false)):
			_finish_failure("native add did not reuse its cached base")
			return
		native_steps.append(_native_step_summary(native_result))
		final_native_result = native_result

	var native_mesh := _array_mesh_from_native_result(final_native_result)
	if native_mesh == null:
		_finish_failure("native final packet did not create an ArrayMesh")
		return
	var oracle_mesh: ArrayMesh = await _build_current_csg_oracle(presenter, bodies)
	if oracle_mesh == null or oracle_mesh.get_surface_count() <= 0:
		_finish_failure("current CSG oracle did not bake")
		return

	# All parity analysis deliberately happens after the native state mutations.
	var native_analysis := MeshAnalyzerScript.analyze_mesh(native_mesh)
	var oracle_analysis := MeshAnalyzerScript.analyze_mesh(oracle_mesh)
	var surface_comparison := MeshAnalyzerScript.compare_surfaces(
		native_analysis, oracle_analysis
	)
	var volume_delta := absf(
		float(native_analysis.get("absolute_volume_cubic_meters", 0.0))
		- float(oracle_analysis.get("absolute_volume_cubic_meters", 0.0))
	)
	var volume_limit := maxf(
		0.0000000005,
		float(oracle_analysis.get("absolute_volume_cubic_meters", 0.0)) * 0.0001
	)
	var bounds_delta := _bounds_delta(native_analysis, oracle_analysis)
	var provenance := _analyze_provenance(final_native_result)

	var publication_material := presenter.call(
		"_build_csg_body_material", MATERIAL_VARIANT_ID, false
	) as StandardMaterial3D
	var publication := _publish_native_mesh(
		native_mesh, final_native_result, publication_material
	)
	if not bool(publication.get("ok", false)):
		_finish_failure(String(publication.get("error", "native publication failed")))
		return
	await physics_frame
	await physics_frame
	var targeting: Dictionary = await _capture_real_resolver_abc_probes(
		final_native_result
	)

	var state_info := backend.call("get_state_info") as Dictionary
	var gates := {
		"three_real_exact_sweeps": sweep_meshes.size() == 3,
		"native_status_and_revision_are_current": (
			bool(state_info.get("ok", false))
			and String(state_info.get("status", "")) == "NoError"
			and int(state_info.get("revision", -1))
			== int(final_native_result.get("revision", -2))
		),
		"native_surface_is_finite_watertight_single_component": (
			_analyzer_topology_passes(native_analysis)
		),
		"csg_oracle_is_finite_watertight_single_component": (
			_analyzer_topology_passes(oracle_analysis)
		),
		"native_surface_matches_current_csg_oracle": (
			float(surface_comparison.get("bidirectional_max_meters", INF))
			<= SURFACE_DISTANCE_LIMIT_METERS
		),
		"native_volume_matches_current_csg_oracle": volume_delta <= volume_limit,
		"native_bounds_match_current_csg_oracle": bounds_delta <= BOUNDS_LIMIT_METERS,
		"native_provenance_is_complete": bool(provenance.get("ok", false)),
		"native_mesh_and_collider_use_forge_publication_contract": (
			bool(publication.get("contract_ok", false))
		),
		"real_placement_target_resolver_returns_three_abc_hits": (
			bool(targeting.get("ok", false))
			and int(targeting.get("hit_count", 0)) == 3
		),
	}
	var passed := true
	for gate_value: Variant in gates.values():
		passed = passed and bool(gate_value)
	_report.merge({
		"ok": passed,
		"outcome": "pass" if passed else "fail",
		"scope": {
			"production_cutover_performed": false,
			"parity_checks_outside_native_timing": true,
			"body_count": bodies.size(),
		},
		"backend": backend.call("get_backend_info"),
		"native_steps": native_steps,
		"native_analysis": _analyzer_summary(native_analysis),
		"csg_oracle_analysis": _analyzer_summary(oracle_analysis),
		"parity": {
			"surface": surface_comparison,
			"surface_limit_meters": SURFACE_DISTANCE_LIMIT_METERS,
			"volume_delta_cubic_meters": volume_delta,
			"volume_limit_cubic_meters": volume_limit,
			"bounds_max_delta_meters": bounds_delta,
			"bounds_limit_meters": BOUNDS_LIMIT_METERS,
		},
		"provenance": provenance,
		"publication": publication,
		"targeting": targeting,
		"state": _strip_packet_arrays(state_info),
		"gates": gates,
	}, true)
	_write_report()
	if passed:
		print("FORGE_V2_NATIVE_MANIFOLD_LIVE_PARITY: PASS")
		quit(0)
	else:
		push_error("FORGE_V2_NATIVE_MANIFOLD_LIVE_PARITY: FAIL")
		quit(1)


func _build_connected_explicit_bodies() -> Array:
	var paths: Array[PackedVector3Array] = [
		PackedVector3Array([
			Vector3(-0.18, 0.000, 0.050), Vector3(0.02, 0.000, 0.050),
		]),
		PackedVector3Array([
			Vector3(-0.03, 0.003, 0.052), Vector3(0.15, 0.006, 0.055),
		]),
		PackedVector3Array([
			Vector3(0.10, 0.004, 0.054), Vector3(0.26, -0.002, 0.058),
		]),
	]
	var polygon := PackedVector2Array([
		Vector2(-0.012, -0.009),
		Vector2(0.010, -0.010),
		Vector2(0.014, -0.003),
		Vector2(0.011, 0.009),
		Vector2(-0.008, 0.012),
		Vector2(-0.014, 0.002),
	])
	var result: Array = []
	for index in range(paths.size()):
		var body: Resource = MaterialBodyScript.new()
		body.set("body_id", StringName("native_parity_stroke_%d" % index))
		body.set("body_kind", MaterialBodyScript.BODY_KIND_VOLUME_STROKE)
		body.set("shape_kind", MaterialBodyScript.SHAPE_KIND_PROFILE_PATH)
		body.set("material_variant_id", MATERIAL_VARIANT_ID)
		body.set("path_points", paths[index])
		body.set("path_surface_normals", PackedVector3Array([
			Vector3.UP, Vector3.UP,
		]))
		body.set("path_contact_directions", PackedVector3Array([
			Vector3.DOWN, Vector3.DOWN,
		]))
		body.set("profile_id", &"native_live_parity_asymmetric_six")
		body.set("profile_display_name", "Native live parity asymmetric six")
		body.set("profile_polygon_2d_meters", polygon)
		body.set("profile_anchor_2d_meters", Vector2.ZERO)
		body.set("profile_contact_point_relative_2d_meters", Vector2(0.0, -0.010))
		body.set("profile_contact_direction_2d", Vector2.DOWN)
		body.set("profile_contact_distance_meters", 0.010)
		body.set("profile_runtime_schema_version", 1)
		body.set("profile_rotation_bias_degrees", 0.0)
		body.call("normalize")
		result.append(body)
	return result


func _mesh_packet(mesh: ArrayMesh) -> Dictionary:
	if mesh == null or mesh.get_surface_count() != 1:
		return {"ok": false}
	var arrays := mesh.surface_get_arrays(0)
	if arrays.size() < Mesh.ARRAY_MAX:
		return {"ok": false}
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	return {
		"ok": not vertices.is_empty() and not indices.is_empty() and indices.size() % 3 == 0,
		"vertices": vertices,
		"indices": indices,
	}


func _array_mesh_from_native_result(native_result: Dictionary) -> ArrayMesh:
	var vertices: PackedVector3Array = native_result.get(
		"vertices", PackedVector3Array()
	)
	var indices: PackedInt32Array = native_result.get(
		"indices", PackedInt32Array()
	)
	if vertices.is_empty() or indices.is_empty() or indices.size() % 3 != 0:
		return null
	# Re-emit the exact native triangle positions through SurfaceTool so the live
	# MeshInstance receives real finite normals without changing its surface.
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex_index: int in indices:
		if vertex_index < 0 or vertex_index >= vertices.size():
			return null
		surface_tool.add_vertex(vertices[vertex_index])
	surface_tool.index()
	surface_tool.generate_normals()
	var mesh := surface_tool.commit()
	return mesh if mesh != null and mesh.get_surface_count() == 1 else null


func _build_current_csg_oracle(presenter: Node, bodies: Array) -> ArrayMesh:
	var combiner := CSGCombiner3D.new()
	combiner.name = "CurrentCsgBakedOracle"
	combiner.operation = CSGShape3D.OPERATION_UNION
	combiner.calculate_tangents = false
	_workspace.add_child(combiner)
	for body_index in range(bodies.size()):
		if not bool(presenter.call(
			"_append_csg_body_shape",
			combiner,
			bodies[body_index],
			MATERIAL_VARIANT_ID,
			false,
			body_index
		)):
			combiner.queue_free()
			return null
	await process_frame
	await process_frame
	var baked := combiner.bake_static_mesh()
	combiner.queue_free()
	return baked


func _publish_native_mesh(
	mesh: ArrayMesh,
	native_result: Dictionary,
	material: StandardMaterial3D
) -> Dictionary:
	var root_node := Node3D.new()
	root_node.name = "NativeManifoldPublication"
	_workspace.add_child(root_node)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "NativeOrganicMesh"
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	_set_publication_metadata(mesh_instance, native_result)
	root_node.add_child(mesh_instance)

	var vertices: PackedVector3Array = native_result.get(
		"vertices", PackedVector3Array()
	)
	var indices: PackedInt32Array = native_result.get(
		"indices", PackedInt32Array()
	)
	var faces := PackedVector3Array()
	faces.resize(indices.size())
	for index_position in range(indices.size()):
		var vertex_index := indices[index_position]
		if vertex_index < 0 or vertex_index >= vertices.size():
			return {"ok": false, "error": "native collision index is invalid"}
		faces[index_position] = vertices[vertex_index]
	var concave := ConcavePolygonShape3D.new()
	concave.backface_collision = false
	concave.set_faces(faces)
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "NativeOrganicConcave"
	collision_shape.shape = concave
	_publication_body = StaticBody3D.new()
	_publication_body.name = "NativeOrganicSurfaceBody"
	_publication_body.collision_layer = (
		PlacementTargetResolverScript.MATERIAL_SURFACE_COLLISION_LAYER
	)
	_publication_body.collision_mask = 0
	_set_publication_metadata(_publication_body, native_result)
	_publication_body.add_child(collision_shape)
	root_node.add_child(_publication_body)
	var render_arrays := mesh.surface_get_arrays(0)
	var render_vertices: PackedVector3Array = render_arrays[Mesh.ARRAY_VERTEX]
	var render_normals: PackedVector3Array = render_arrays[Mesh.ARRAY_NORMAL]
	var normals_valid := render_normals.size() == render_vertices.size()
	for normal: Vector3 in render_normals:
		if not normal.is_finite() or normal.length_squared() <= 0.5:
			normals_valid = false
			break
	var material_valid := (
		material != null
		and mesh_instance.material_override == material
		and material.albedo_color.a >= 0.999
		and material.emission_enabled
		and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
		and material.cull_mode == BaseMaterial3D.CULL_DISABLED
		and is_equal_approx(material.roughness, 0.54)
		and is_equal_approx(material.metallic, 0.12)
	)
	var contract_ok := (
		root_node.transform.is_equal_approx(Transform3D.IDENTITY)
		and mesh_instance.transform.is_equal_approx(Transform3D.IDENTITY)
		and _publication_body.transform.is_equal_approx(Transform3D.IDENTITY)
		and collision_shape.transform.is_equal_approx(Transform3D.IDENTITY)
		and _publication_body.collision_layer == 1 << 20
		and StringName(_publication_body.get_meta("forge_v2_surface_target_id"))
		== SURFACE_TARGET_ID
		and StringName(_publication_body.get_meta("forge_v2_body_id"))
		== LOGICAL_BODY_ID
		and StringName(_publication_body.get_meta("forge_v2_material_variant_id"))
		== MATERIAL_VARIANT_ID
		and normals_valid
		and material_valid
	)
	return {
		"ok": true,
		"contract_ok": contract_ok,
		"collision_layer": _publication_body.collision_layer,
		"surface_target_id": String(SURFACE_TARGET_ID),
		"logical_body_id": String(LOGICAL_BODY_ID),
		"material_variant_id": String(MATERIAL_VARIANT_ID),
		"triangle_count": indices.size() / 3,
		"native_revision": int(native_result.get("revision", -1)),
		"render_vertex_count": render_vertices.size(),
		"render_normal_count": render_normals.size(),
		"finite_nonzero_normals": normals_valid,
		"presenter_material_override": material_valid,
	}


func _set_publication_metadata(node: Node, native_result: Dictionary) -> void:
	node.set_meta("forge_v2_material_surface", true)
	node.set_meta("forge_v2_surface_target_id", SURFACE_TARGET_ID)
	node.set_meta("forge_v2_body_id", LOGICAL_BODY_ID)
	node.set_meta("forge_v2_material_variant_id", MATERIAL_VARIANT_ID)
	node.set_meta("forge_v2_native_revision", int(native_result.get("revision", -1)))


func _capture_real_resolver_abc_probes(native_result: Dictionary) -> Dictionary:
	var camera := _workspace.get("camera") as Camera3D
	if camera == null or _publication_body == null:
		return {"ok": false, "error": "workspace camera or native collider is missing"}
	var vertices: PackedVector3Array = native_result.get(
		"vertices", PackedVector3Array()
	)
	var indices: PackedInt32Array = native_result.get(
		"indices", PackedInt32Array()
	)
	var candidates: Array[Dictionary] = []
	for triangle in range(indices.size() / 3):
		var a := vertices[indices[triangle * 3]]
		var b := vertices[indices[triangle * 3 + 1]]
		var c := vertices[indices[triangle * 3 + 2]]
		var cross := (b - a).cross(c - a)
		if cross.length_squared() <= 0.000000000001:
			continue
		candidates.append({
			"triangle": triangle,
			"center": (a + b + c) / 3.0,
			# Native output is already reversed once into Godot's clockwise
			# front-face order. Its physical outward normal is therefore the
			# opposite of the mathematical index cross product.
			"normal": -cross.normalized(),
			"area_squared": cross.length_squared(),
		})
	candidates.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return float(first.get("area_squared", 0.0)) > float(second.get("area_squared", 0.0))
	)
	var hits: Array[Dictionary] = []
	for candidate_variant: Variant in candidates:
		if hits.size() >= PROBE_LABELS.size():
			break
		var candidate := candidate_variant as Dictionary
		var center := candidate.get("center", Vector3.ZERO) as Vector3
		var normal := candidate.get("normal", Vector3.ZERO) as Vector3
		var separated := true
		for prior: Dictionary in hits:
			if center.distance_to(prior.get("expected_position", Vector3.ZERO)) < 0.008:
				separated = false
				break
		if not separated or not _direct_probe_matches(center, normal):
			continue
		var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.94 else Vector3.RIGHT
		camera.global_position = _workspace.to_global(
			center + normal * CAMERA_DISTANCE_METERS
		)
		camera.look_at(_workspace.to_global(center), up)
		camera.current = true
		camera.near = 0.005
		camera.far = 2.0
		await process_frame
		var projection := _workspace.call(
			"project_workspace_local_to_screen", center
		) as Dictionary
		if not bool(projection.get("valid", false)):
			continue
		var hit := _workspace.call(
			"resolve_strict_surface_target",
			projection.get("screen_position", Vector2.ZERO),
			PlacementTargetResolverScript.TARGET_KIND_MATERIAL_SURFACE,
			SURFACE_TARGET_ID
		) as Dictionary
		var validation := _validate_resolver_hit(hit, center, normal)
		if not bool(validation.get("ok", false)):
			continue
		hits.append({
			"label": PROBE_LABELS[hits.size()],
			"triangle": int(candidate.get("triangle", -1)),
			"expected_position": center,
			"expected_normal": normal,
			"resolved_position": hit.get("local_position", Vector3.ZERO),
			"resolved_normal": hit.get("local_normal", Vector3.ZERO),
			"contact_direction": hit.get("local_contact_direction", Vector3.ZERO),
			"position_error_meters": validation.get("position_error_meters", INF),
			"normal_dot": validation.get("normal_dot", 0.0),
			"abc_normal_dot_contact": validation.get("abc_dot", 1.0),
		})
	var resolver := _workspace.get("placement_target_resolver") as Object
	var real_resolver: bool = (
		resolver != null and resolver.get_script() == PlacementTargetResolverScript
	)
	return {
		"ok": hits.size() == PROBE_LABELS.size() and real_resolver,
		"hit_count": hits.size(),
		"real_placement_target_resolver": real_resolver,
		"hits": hits,
	}


func _direct_probe_matches(center: Vector3, normal: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		_workspace.to_global(center + normal * DIRECT_RAY_OFFSET_METERS),
		_workspace.to_global(center - normal * DIRECT_RAY_OFFSET_METERS),
		PlacementTargetResolverScript.MATERIAL_SURFACE_COLLISION_LAYER
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := _workspace.get_world_3d().direct_space_state.intersect_ray(query)
	var collider := hit.get("collider", null) as Object
	if hit.is_empty() or collider != _publication_body:
		return false
	var local_position := _workspace.to_local(hit.get("position", Vector3.ZERO))
	var local_normal := (
		_workspace.global_transform.basis.inverse()
		* (hit.get("normal", Vector3.ZERO) as Vector3)
	).normalized()
	return (
		local_position.distance_to(center) <= HIT_POSITION_LIMIT_METERS
		and local_normal.dot(normal) >= NORMAL_DOT_MIN
	)


func _validate_resolver_hit(
	hit: Dictionary, expected_position: Vector3, expected_normal: Vector3
) -> Dictionary:
	var actual_position := hit.get("local_position", Vector3.ZERO) as Vector3
	var actual_normal := (
		hit.get("local_normal", Vector3.ZERO) as Vector3
	).normalized()
	var contact := (
		hit.get("local_contact_direction", Vector3.ZERO) as Vector3
	).normalized()
	var position_error := actual_position.distance_to(expected_position)
	var normal_dot := actual_normal.dot(expected_normal)
	var abc_dot := actual_normal.dot(contact)
	var collider := hit.get("collider", null) as Object
	var ok := (
		bool(hit.get("valid", false))
		and collider == _publication_body
		and StringName(hit.get("target_kind", StringName()))
		== PlacementTargetResolverScript.TARGET_KIND_MATERIAL_SURFACE
		and StringName(hit.get("surface_target_id", StringName())) == SURFACE_TARGET_ID
		and StringName(hit.get("source_body_id", StringName())) == LOGICAL_BODY_ID
		and StringName(hit.get("source_record_id", StringName())) == MATERIAL_VARIANT_ID
		and not bool(hit.get("is_clamped", true))
		and position_error <= HIT_POSITION_LIMIT_METERS
		and normal_dot >= NORMAL_DOT_MIN
		and abc_dot <= ABC_DOT_MAX
	)
	return {
		"ok": ok,
		"position_error_meters": position_error,
		"normal_dot": normal_dot,
		"abc_dot": abc_dot,
	}


func _analyzer_topology_passes(analysis: Dictionary) -> bool:
	return (
		int(analysis.get("triangle_count", 0)) > 0
		and int(analysis.get("nonfinite_vertex_count", -1)) == 0
		and int(analysis.get("degenerate_triangle_count", -1)) == 0
		and bool(analysis.get("strict_watertight", false))
		and int(analysis.get("strict_component_count", -1)) == 1
		and int(analysis.get("strict_boundary_edge_count", -1)) == 0
		and int(analysis.get("strict_nonmanifold_edge_count", -1)) == 0
		and int(analysis.get("strict_directed_edge_mismatch_count", -1)) == 0
	)


func _analyze_provenance(native_result: Dictionary) -> Dictionary:
	var triangle_count := int(native_result.get("output_triangle_count", -1))
	var source_ids: PackedInt32Array = native_result.get(
		"source_original_ids", PackedInt32Array()
	)
	var face_ids: PackedInt32Array = native_result.get(
		"source_face_ids", PackedInt32Array()
	)
	var base_count := source_ids.count(0)
	var current_count := source_ids.count(1)
	var unknown_count := source_ids.size() - base_count - current_count
	var invalid_face_count := 0
	for face_id: int in face_ids:
		if face_id < 0:
			invalid_face_count += 1
	return {
		"ok": (
			triangle_count > 0
			and source_ids.size() == triangle_count
			and face_ids.size() == triangle_count
			and base_count > 0
			and current_count > 0
			and unknown_count == 0
			and invalid_face_count == 0
		),
		"triangle_count": triangle_count,
		"cached_history_triangle_count": base_count,
		"current_operand_triangle_count": current_count,
		"unknown_source_triangle_count": unknown_count,
		"invalid_face_id_count": invalid_face_count,
	}


func _native_step_summary(result: Dictionary) -> Dictionary:
	var summary := _strip_packet_arrays(result)
	return summary


func _strip_packet_arrays(value: Dictionary) -> Dictionary:
	var summary := value.duplicate(false)
	summary.erase("vertices")
	summary.erase("indices")
	summary.erase("source_original_ids")
	summary.erase("source_face_ids")
	return summary


func _analyzer_summary(analysis: Dictionary) -> Dictionary:
	var summary := analysis.duplicate(false)
	summary.erase("triangle_positions")
	summary.erase("surface_sample_points")
	return summary


func _bounds_delta(first: Dictionary, second: Dictionary) -> float:
	var maximum := 0.0
	for suffix: String in [
		"position_x", "position_y", "position_z", "size_x", "size_y", "size_z"
	]:
		maximum = maxf(maximum, absf(
			float(first.get("aabb_%s" % suffix, INF))
			- float(second.get("aabb_%s" % suffix, -INF))
		))
	return maximum


func _finish_failure(message: String) -> void:
	_report["failure_reason"] = message
	_report["outcome"] = "fail"
	_write_report()
	push_error("FORGE_V2_NATIVE_MANIFOLD_LIVE_PARITY: %s" % message)
	quit(1)


func _write_report() -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report, "\t"))
