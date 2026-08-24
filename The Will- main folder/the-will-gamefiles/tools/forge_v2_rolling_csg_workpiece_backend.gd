extends RefCounted

const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2VolumeStrokeScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_stroke.gd"
)

const BACKEND_ID := &"rolling_builtin_csg_bake_v1"
const BACKEND_SCHEMA_VERSION := 1
const DEFAULT_SETTLE_FRAME_COUNT := 3
const DEFAULT_ABSORPTION_WINDOW_SIZE := 1
const MAX_ABSORPTION_WINDOW_SIZE := 15

var host_node: Node3D = null
var presenter: Node3D = null
var accepted_mesh_instance: MeshInstance3D = null
var accepted_mesh: ArrayMesh = null
var accepted_base_mesh: ArrayMesh = null
var accepted_revision: int = 0
var accepted_base_revision: int = 0
var accepted_material_variant_id: StringName = StringName()
var accepted_material: Material = null
var accepted_source_body_count: int = 0
var absorption_window_size: int = DEFAULT_ABSORPTION_WINDOW_SIZE
var pending_bodies: Array[Resource] = []


func initialize(
	next_host_node: Node3D,
	next_presenter: Node3D,
	next_absorption_window_size: int = DEFAULT_ABSORPTION_WINDOW_SIZE
) -> Dictionary:
	if next_host_node == null or next_presenter == null:
		return {
			"ok": false,
			"error": "rolling_backend_host_or_presenter_missing",
		}
	host_node = next_host_node
	presenter = next_presenter
	absorption_window_size = clampi(
		next_absorption_window_size,
		1,
		MAX_ABSORPTION_WINDOW_SIZE
	)
	accepted_mesh_instance = MeshInstance3D.new()
	accepted_mesh_instance.name = "AcceptedRollingWorkpieceMesh"
	accepted_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host_node.add_child(accepted_mesh_instance)
	return {
		"ok": true,
		"backend_id": String(BACKEND_ID),
		"backend_schema": BACKEND_SCHEMA_VERSION,
		"absorption_window_size": absorption_window_size,
	}


func reset() -> void:
	accepted_mesh = null
	accepted_base_mesh = null
	accepted_revision = 0
	accepted_base_revision = 0
	accepted_material_variant_id = StringName()
	accepted_material = null
	accepted_source_body_count = 0
	pending_bodies = []
	if accepted_mesh_instance != null and is_instance_valid(accepted_mesh_instance):
		accepted_mesh_instance.mesh = null


func initialize_seed(body: Resource) -> Dictionary:
	if accepted_mesh != null or accepted_revision != 0:
		return {
			"ok": false,
			"error": "rolling_backend_seed_already_initialized",
		}
	var validation := _validate_supported_body(body)
	if not bool(validation.get("ok", false)):
		return validation
	var material_variant_id := StringName(body.get("material_variant_id"))
	var material := presenter.call(
		"_build_csg_body_material",
		material_variant_id,
		false
	) as Material
	var seed_mesh := presenter.call(
		"_build_active_material_body_sweep_mesh",
		body
	) as ArrayMesh
	if seed_mesh == null or seed_mesh.get_surface_count() <= 0:
		return {
			"ok": false,
			"error": "rolling_backend_seed_mesh_missing",
		}
	for surface_index in range(seed_mesh.get_surface_count()):
		seed_mesh.surface_set_material(surface_index, material)
	var consolidated_mesh := _consolidate_single_material_mesh(
		seed_mesh,
		material
	)
	if consolidated_mesh == null or consolidated_mesh.get_surface_count() != 1:
		return {
			"ok": false,
			"error": "rolling_backend_seed_consolidation_failed",
		}
	accepted_mesh = consolidated_mesh
	accepted_base_mesh = consolidated_mesh
	accepted_material_variant_id = material_variant_id
	accepted_material = material
	accepted_source_body_count = 1
	accepted_mesh_instance.mesh = accepted_mesh
	accepted_mesh_instance.visible = true
	return {
		"ok": true,
		"accepted_revision": accepted_revision,
		"accepted_source_body_count": accepted_source_body_count,
		"accepted_base_revision": accepted_base_revision,
		"pending_body_count": pending_bodies.size(),
		"absorption_window_size": absorption_window_size,
		"accepted_surface_count": accepted_mesh.get_surface_count(),
		"steady_csg_shape_count": 0,
		"steady_csg_operand_count": 0,
	}


func dispose() -> void:
	reset()
	if accepted_mesh_instance != null and is_instance_valid(accepted_mesh_instance):
		if accepted_mesh_instance.get_parent() != null:
			accepted_mesh_instance.get_parent().remove_child(accepted_mesh_instance)
		accepted_mesh_instance.free()
	accepted_mesh_instance = null
	host_node = null
	presenter = null


func apply_add_body(
	body: Resource,
	settle_frame_count: int = DEFAULT_SETTLE_FRAME_COUNT,
	measure_collision: bool = false
) -> Dictionary:
	var validation := _validate_supported_body(body)
	if not bool(validation.get("ok", false)):
		return validation
	var material_variant_id := StringName(body.get("material_variant_id"))
	var candidate_material_variant_id := accepted_material_variant_id
	var candidate_material := accepted_material
	if candidate_material_variant_id == StringName():
		candidate_material_variant_id = material_variant_id
		candidate_material = presenter.call(
			"_build_csg_body_material",
			material_variant_id,
			false
		) as Material
	elif material_variant_id != candidate_material_variant_id:
		return {
			"ok": false,
			"error": "rolling_backend_v1_multiple_materials_unsupported",
			"expected_material_id": String(candidate_material_variant_id),
			"received_material_id": String(material_variant_id),
		}

	var compile_started := Time.get_ticks_usec()
	var candidate_pending_bodies: Array[Resource] = []
	candidate_pending_bodies.append_array(pending_bodies)
	candidate_pending_bodies.append(body)
	var staging_root := CSGCombiner3D.new()
	staging_root.name = "RollingCompileRevision_%04d" % (accepted_revision + 1)
	staging_root.operation = CSGShape3D.OPERATION_UNION
	staging_root.calculate_tangents = false
	staging_root.use_collision = false
	host_node.add_child(staging_root)

	var node_build_started := Time.get_ticks_usec()
	if accepted_base_mesh != null:
		var accepted_base := CSGMesh3D.new()
		accepted_base.name = "AcceptedBase"
		accepted_base.operation = CSGShape3D.OPERATION_UNION
		accepted_base.calculate_tangents = false
		accepted_base.mesh = accepted_base_mesh
		staging_root.add_child(accepted_base)
	for pending_index in range(candidate_pending_bodies.size()):
		var pending_body: Resource = candidate_pending_bodies[pending_index]
		var operation_mesh := presenter.call(
			"_build_active_material_body_sweep_mesh",
			pending_body
		) as ArrayMesh
		if operation_mesh == null or operation_mesh.get_surface_count() <= 0:
			_discard_staging_root(staging_root)
			return {
				"ok": false,
				"error": "rolling_backend_operand_generation_failed",
				"pending_index": pending_index,
			}
		for surface_index in range(operation_mesh.get_surface_count()):
			operation_mesh.surface_set_material(surface_index, candidate_material)
		var operation_shape := CSGMesh3D.new()
		operation_shape.name = "AcceptedOperation_%04d_%02d" % [
			accepted_revision + 1,
			pending_index,
		]
		operation_shape.operation = CSGShape3D.OPERATION_UNION
		operation_shape.calculate_tangents = false
		operation_shape.mesh = operation_mesh
		staging_root.add_child(operation_shape)
	var node_build_ms := _elapsed_milliseconds(node_build_started)
	var compile_node_counts := _count_csg_nodes(staging_root)

	var normalized_settle_count := maxi(settle_frame_count, 1)
	var frame_gaps_ms: Array[float] = []
	var settle_started := Time.get_ticks_usec()
	for _frame_index in range(normalized_settle_count):
		var frame_started := Time.get_ticks_usec()
		await host_node.get_tree().process_frame
		frame_gaps_ms.append(_elapsed_milliseconds(frame_started))
	var settle_wall_ms := _elapsed_milliseconds(settle_started)

	var static_bake_started := Time.get_ticks_usec()
	var baked_mesh := staging_root.bake_static_mesh()
	var static_bake_ms := _elapsed_milliseconds(static_bake_started)
	if baked_mesh == null or baked_mesh.get_surface_count() <= 0:
		_discard_staging_root(staging_root)
		return {
			"ok": false,
			"error": "rolling_backend_bake_empty",
			"node_build_ms": node_build_ms,
			"settle_wall_ms": settle_wall_ms,
			"static_bake_ms": static_bake_ms,
		}

	var collision_bake_ms := 0.0
	var collision_face_count := 0
	if measure_collision:
		var collision_started := Time.get_ticks_usec()
		var collision_shape := staging_root.bake_collision_shape()
		if collision_shape != null:
			collision_face_count = int(collision_shape.get_faces().size() / 3.0)
		collision_bake_ms = _elapsed_milliseconds(collision_started)

	var consolidation_started := Time.get_ticks_usec()
	var consolidated_mesh := _consolidate_single_material_mesh(
		baked_mesh,
		candidate_material
	)
	var consolidation_ms := _elapsed_milliseconds(consolidation_started)
	if consolidated_mesh == null or consolidated_mesh.get_surface_count() != 1:
		_discard_staging_root(staging_root)
		return {
			"ok": false,
			"error": "rolling_backend_surface_consolidation_failed",
		}

	accepted_mesh = consolidated_mesh
	accepted_material_variant_id = candidate_material_variant_id
	accepted_material = candidate_material
	accepted_revision += 1
	accepted_source_body_count += 1
	pending_bodies = candidate_pending_bodies
	if pending_bodies.size() >= absorption_window_size:
		accepted_base_mesh = accepted_mesh
		accepted_base_revision = accepted_revision
		pending_bodies = []
	accepted_mesh_instance.mesh = accepted_mesh
	accepted_mesh_instance.visible = true
	_discard_staging_root(staging_root)
	var steady_counts := _count_csg_nodes(host_node)
	return {
		"ok": true,
		"backend_id": String(BACKEND_ID),
		"backend_schema": BACKEND_SCHEMA_VERSION,
		"accepted_revision": accepted_revision,
		"accepted_source_body_count": accepted_source_body_count,
		"accepted_base_revision": accepted_base_revision,
		"pending_body_count": pending_bodies.size(),
		"absorption_window_size": absorption_window_size,
		"accepted_surface_count": accepted_mesh.get_surface_count(),
		"accepted_display_mesh_count": 1,
		"node_build_ms": node_build_ms,
		"settle_wall_ms": settle_wall_ms,
		"max_frame_gap_ms": _maximum_float(frame_gaps_ms),
		"static_bake_ms": static_bake_ms,
		"collision_bake_ms": collision_bake_ms,
		"collision_face_count": collision_face_count,
		"surface_consolidation_ms": consolidation_ms,
		"operation_compile_total_ms": _elapsed_milliseconds(compile_started),
		"compile_scene_node_count": int(compile_node_counts.get(
			"scene_node_count",
			0
		)),
		"compile_csg_shape_count": int(compile_node_counts.get(
			"csg_shape_count",
			0
		)),
		"compile_csg_combiner_count": int(compile_node_counts.get(
			"csg_combiner_count",
			0
		)),
		"compile_csg_operand_count": int(compile_node_counts.get(
			"csg_operand_count",
			0
		)),
		"steady_csg_shape_count": int(steady_counts.get(
			"csg_shape_count",
			0
		)),
		"steady_csg_operand_count": int(steady_counts.get(
			"csg_operand_count",
			0
		)),
	}


func get_accepted_mesh() -> ArrayMesh:
	return accepted_mesh


func get_accepted_revision() -> int:
	return accepted_revision


func _validate_supported_body(body: Resource) -> Dictionary:
	if host_node == null or presenter == null:
		return {
			"ok": false,
			"error": "rolling_backend_not_initialized",
		}
	if body == null:
		return {
			"ok": false,
			"error": "rolling_backend_body_missing",
		}
	if StringName(body.get("body_kind")) != ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE:
		return {
			"ok": false,
			"error": "rolling_backend_v1_body_kind_unsupported",
		}
	if StringName(body.get("operation_mode")) != ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL:
		return {
			"ok": false,
			"error": "rolling_backend_v1_operation_unsupported",
		}
	if StringName(body.get("placement_policy")) != ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING:
		return {
			"ok": false,
			"error": "rolling_backend_v1_placement_policy_unsupported",
		}
	if StringName(body.get("shape_kind")) != ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH:
		return {
			"ok": false,
			"error": "rolling_backend_v1_shape_kind_unsupported",
		}
	if not bool(body.call("uses_explicit_surface_contact_authority")):
		return {
			"ok": false,
			"error": "rolling_backend_v1_explicit_surface_frame_required",
		}
	return {"ok": true}


func _consolidate_single_material_mesh(
	mesh: ArrayMesh,
	material: Material
) -> ArrayMesh:
	if mesh == null or mesh.get_surface_count() <= 0:
		return null
	var combined_vertices := PackedVector3Array()
	var combined_normals := PackedVector3Array()
	var combined_uvs := PackedVector2Array()
	var combined_indices := PackedInt32Array()
	var all_normals_paired := true
	var all_uvs_paired := true
	for surface_index in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		if arrays.size() <= Mesh.ARRAY_VERTEX:
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if vertices.is_empty():
			continue
		var normals := PackedVector3Array()
		if (
			arrays.size() > Mesh.ARRAY_NORMAL
			and arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array
		):
			normals = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		var uvs := PackedVector2Array()
		if (
			arrays.size() > Mesh.ARRAY_TEX_UV
			and arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array
		):
			uvs = arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		var indices := PackedInt32Array()
		if (
			arrays.size() > Mesh.ARRAY_INDEX
			and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array
		):
			indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var vertex_offset := combined_vertices.size()
		combined_vertices.append_array(vertices)
		if normals.size() == vertices.size():
			combined_normals.append_array(normals)
		else:
			all_normals_paired = false
		if uvs.size() == vertices.size():
			combined_uvs.append_array(uvs)
		else:
			all_uvs_paired = false
		if indices.is_empty():
			for local_vertex_index in range(vertices.size()):
				combined_indices.append(vertex_offset + local_vertex_index)
		else:
			for local_index: int in indices:
				combined_indices.append(vertex_offset + local_index)
	if combined_vertices.is_empty() or combined_indices.is_empty():
		return null
	var combined_arrays := []
	combined_arrays.resize(Mesh.ARRAY_MAX)
	combined_arrays[Mesh.ARRAY_VERTEX] = combined_vertices
	combined_arrays[Mesh.ARRAY_INDEX] = combined_indices
	if all_normals_paired and combined_normals.size() == combined_vertices.size():
		combined_arrays[Mesh.ARRAY_NORMAL] = combined_normals
	if all_uvs_paired and combined_uvs.size() == combined_vertices.size():
		combined_arrays[Mesh.ARRAY_TEX_UV] = combined_uvs
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, combined_arrays)
	result.surface_set_material(0, material)
	return result


func _discard_staging_root(staging_root: Node) -> void:
	if staging_root == null or not is_instance_valid(staging_root):
		return
	if staging_root.get_parent() != null:
		staging_root.get_parent().remove_child(staging_root)
	staging_root.free()


func _count_csg_nodes(parent: Node) -> Dictionary:
	var counts := {
		"scene_node_count": 0,
		"csg_shape_count": 0,
		"csg_combiner_count": 0,
		"csg_operand_count": 0,
	}
	_count_csg_nodes_recursive(parent, counts)
	return counts


func _count_csg_nodes_recursive(node: Node, counts: Dictionary) -> void:
	if node == null:
		return
	counts["scene_node_count"] = int(counts["scene_node_count"]) + 1
	if node is CSGShape3D:
		counts["csg_shape_count"] = int(counts["csg_shape_count"]) + 1
		if node is CSGCombiner3D:
			counts["csg_combiner_count"] = int(
				counts["csg_combiner_count"]
			) + 1
		else:
			counts["csg_operand_count"] = int(
				counts["csg_operand_count"]
			) + 1
	for child: Node in node.get_children():
		_count_csg_nodes_recursive(child, counts)


func _elapsed_milliseconds(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


func _maximum_float(values: Array[float]) -> float:
	var result := 0.0
	for value: float in values:
		result = maxf(result, value)
	return result
