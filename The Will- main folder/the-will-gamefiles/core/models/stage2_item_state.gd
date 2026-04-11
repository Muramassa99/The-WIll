extends Resource
class_name Stage2ItemState

const CraftedItemCanonicalGeometryScript = preload("res://core/models/crafted_item_canonical_geometry.gd")
const CraftedItemCanonicalSurfaceQuadScript = preload("res://core/models/crafted_item_canonical_surface_quad.gd")
const CraftedItemCanonicalSurfaceTriangleScript = preload("res://core/models/crafted_item_canonical_surface_triangle.gd")

const EDGE_U_MIN: StringName = &"edge_u_min"
const EDGE_U_MAX: StringName = &"edge_u_max"
const EDGE_V_MIN: StringName = &"edge_v_min"
const EDGE_V_MAX: StringName = &"edge_v_max"

@export var stage2_version: int = 1
@export var source_wip_id: StringName = &""
@export var source_stage1_cell_count: int = 0
@export var cell_world_size_meters: float = 0.0125
@export var baseline_local_aabb_position: Vector3 = Vector3.ZERO
@export var baseline_local_aabb_size: Vector3 = Vector3.ZERO
@export var current_local_aabb_position: Vector3 = Vector3.ZERO
@export var current_local_aabb_size: Vector3 = Vector3.ZERO
@export var baseline_editable_mesh_state: Resource
@export var current_editable_mesh_state: Resource
@export var baseline_shell_mesh_state: Resource
@export var current_shell_mesh_state: Resource
@export var patch_states: Array[Resource] = []
@export var refinement_initialized: bool = false
@export var dirty: bool = false
@export var editable_mesh_visual_authority: bool = false
@export var last_active_tool_id: StringName = &""

func has_current_shell() -> bool:
	return refinement_initialized and (has_unified_shell() or not patch_states.is_empty())

func has_current_editable_mesh() -> bool:
	return (
		current_editable_mesh_state != null
		and current_editable_mesh_state.has_method("has_surface_arrays")
		and bool(current_editable_mesh_state.call("has_surface_arrays"))
	)

func get_patch_count() -> int:
	return patch_states.size()

func get_unified_shell_quad_count() -> int:
	if current_shell_mesh_state == null or not current_shell_mesh_state.has_method("get_quad_count"):
		return 0
	return int(current_shell_mesh_state.call("get_quad_count"))

func has_unified_shell() -> bool:
	if current_shell_mesh_state == null or not current_shell_mesh_state.has_method("has_shell_geometry"):
		return false
	return bool(current_shell_mesh_state.call("has_shell_geometry"))

func build_current_canonical_geometry(source_solid = null):
	if _should_build_canonical_geometry_from_editable_mesh():
		var editable_mesh_geometry = _build_current_canonical_geometry_from_editable_mesh(source_solid)
		if editable_mesh_geometry != null and not editable_mesh_geometry.is_empty():
			return editable_mesh_geometry
	if has_unified_shell():
		return _build_current_canonical_geometry_with_unified_shell_overlay(source_solid)
	return _build_current_canonical_geometry_internal(source_solid)

func build_current_canonical_geometry_without_transition_walls_for_shell_quad_ids(
	shell_quad_ids: PackedStringArray,
	source_solid = null
):
	if not has_unified_shell():
		return build_current_canonical_geometry(source_solid)
	var shell_quad_lookup: Dictionary = {}
	for shell_quad_id: String in shell_quad_ids:
		shell_quad_lookup[StringName(shell_quad_id)] = true
	return _build_current_canonical_geometry_with_unified_shell_overlay(source_solid, shell_quad_lookup, false)

func count_secondary_diagonal_cells_for_shell_quad_ids(shell_quad_ids: PackedStringArray) -> int:
	if not has_unified_shell() or shell_quad_ids.is_empty():
		return 0
	var restricted_shell_quad_lookup: Dictionary = {}
	for shell_quad_id: String in shell_quad_ids:
		restricted_shell_quad_lookup[StringName(shell_quad_id)] = true
	var patch_states_by_shell_quad_id: Dictionary = _build_patch_states_by_shell_quad_id()
	var secondary_diagonal_count: int = 0
	for shell_quad_state: Resource in current_shell_mesh_state.shell_quads:
		if shell_quad_state == null or shell_quad_state.shell_quad_id == StringName():
			continue
		if not restricted_shell_quad_lookup.has(shell_quad_state.shell_quad_id):
			continue
		var shell_patch_states: Array = patch_states_by_shell_quad_id.get(shell_quad_state.shell_quad_id, [])
		if shell_patch_states.is_empty():
			continue
		secondary_diagonal_count += _count_secondary_diagonal_cells_for_shell_quad(
			shell_quad_state,
			shell_patch_states
		)
	return secondary_diagonal_count

func count_center_subdivided_cells_for_shell_quad_ids(shell_quad_ids: PackedStringArray) -> int:
	if not has_unified_shell() or shell_quad_ids.is_empty():
		return 0
	var restricted_shell_quad_lookup: Dictionary = {}
	for shell_quad_id: String in shell_quad_ids:
		restricted_shell_quad_lookup[StringName(shell_quad_id)] = true
	var patch_states_by_shell_quad_id: Dictionary = _build_patch_states_by_shell_quad_id()
	var subdivided_cell_count: int = 0
	for shell_quad_state: Resource in current_shell_mesh_state.shell_quads:
		if shell_quad_state == null or shell_quad_state.shell_quad_id == StringName():
			continue
		if not restricted_shell_quad_lookup.has(shell_quad_state.shell_quad_id):
			continue
		var shell_patch_states: Array = patch_states_by_shell_quad_id.get(shell_quad_state.shell_quad_id, [])
		if shell_patch_states.is_empty():
			continue
		subdivided_cell_count += _count_center_subdivided_cells_for_shell_quad(
			shell_quad_state,
			shell_patch_states
		)
	return subdivided_cell_count

func count_edge_midpoint_subdivided_cells_for_shell_quad_ids(shell_quad_ids: PackedStringArray) -> int:
	return count_center_subdivided_cells_for_shell_quad_ids(shell_quad_ids)

func build_current_canonical_geometry_for_patch_ids(patch_ids: PackedStringArray, source_solid = null):
	if patch_ids.is_empty():
		var canonical_geometry = CraftedItemCanonicalGeometryScript.new()
		canonical_geometry.source_solid = source_solid
		canonical_geometry.local_aabb = AABB(current_local_aabb_position, current_local_aabb_size)
		return canonical_geometry
	var patch_id_lookup: Dictionary = {}
	for patch_id: String in patch_ids:
		patch_id_lookup[StringName(patch_id)] = true
	return _build_current_canonical_geometry_internal(source_solid, patch_id_lookup)

func build_current_canonical_geometry_for_face_ids(face_ids: PackedStringArray, source_solid = null):
	if face_ids.is_empty():
		var canonical_geometry = CraftedItemCanonicalGeometryScript.new()
		canonical_geometry.source_solid = source_solid
		canonical_geometry.local_aabb = AABB(current_local_aabb_position, current_local_aabb_size)
		return canonical_geometry
	if has_unified_shell():
		return build_current_canonical_geometry_without_transition_walls_for_shell_quad_ids(face_ids, source_solid)
	return build_current_canonical_geometry_for_patch_ids(resolve_patch_ids_for_face_ids(face_ids), source_solid)

func resolve_patch_ids_for_face_ids(face_ids: PackedStringArray) -> PackedStringArray:
	if face_ids.is_empty():
		return PackedStringArray()
	var face_lookup: Dictionary = {}
	for face_id: String in face_ids:
		if face_id.is_empty():
			continue
		face_lookup[StringName(face_id)] = true
	var unique_patch_lookup: Dictionary = {}
	var patch_ids: PackedStringArray = PackedStringArray()
	for patch_state in patch_states:
		if patch_state == null or patch_state.patch_id == StringName():
			continue
		if not face_lookup.has(patch_state.shell_quad_id):
			continue
		if unique_patch_lookup.has(patch_state.patch_id):
			continue
		unique_patch_lookup[patch_state.patch_id] = true
		patch_ids.append(String(patch_state.patch_id))
	return patch_ids

func resolve_shell_face_ids_for_brush_sphere(
	hit_point_local: Vector3,
	radius_meters: float,
	preferred_face_id: StringName = StringName()
) -> PackedStringArray:
	if not has_unified_shell():
		return PackedStringArray()
	var cell_size_meters: float = maxf(cell_world_size_meters, 0.0001)
	var radius_cells: float = radius_meters / cell_size_meters
	if radius_cells <= 0.0:
		return PackedStringArray()
	var unique_face_lookup: Dictionary = {}
	var shell_face_ids: PackedStringArray = PackedStringArray()
	if preferred_face_id != StringName() and get_current_shell_quad_state_by_id(preferred_face_id) != null:
		unique_face_lookup[preferred_face_id] = true
		shell_face_ids.append(String(preferred_face_id))
	if current_shell_mesh_state == null:
		return shell_face_ids
	for shell_quad_state in current_shell_mesh_state.shell_quads:
		if shell_quad_state == null or shell_quad_state.shell_quad_id == StringName():
			continue
		if unique_face_lookup.has(shell_quad_state.shell_quad_id):
			continue
		if _distance_point_to_shell_quad(hit_point_local, shell_quad_state) > radius_cells:
			continue
		unique_face_lookup[shell_quad_state.shell_quad_id] = true
		shell_face_ids.append(String(shell_quad_state.shell_quad_id))
	return shell_face_ids

func resolve_patch_ids_for_brush_sphere(
	hit_point_local: Vector3,
	radius_meters: float,
	preferred_face_id: StringName = StringName()
) -> PackedStringArray:
	var candidate_patch_records: Array[Dictionary] = resolve_shell_brush_candidate_records_for_sphere(
		hit_point_local,
		radius_meters,
		preferred_face_id
	)
	if candidate_patch_records.is_empty():
		return PackedStringArray()
	var unique_patch_lookup: Dictionary = {}
	var patch_ids: PackedStringArray = PackedStringArray()
	for candidate_patch_record: Dictionary in candidate_patch_records:
		var patch_id: StringName = StringName(candidate_patch_record.get("patch_id", StringName()))
		if patch_id == StringName() or unique_patch_lookup.has(patch_id):
			continue
		unique_patch_lookup[patch_id] = true
		patch_ids.append(String(patch_id))
	return patch_ids

func resolve_shell_brush_candidate_records_for_sphere(
	hit_point_local: Vector3,
	radius_meters: float,
	preferred_face_id: StringName = StringName()
) -> Array[Dictionary]:
	if _should_use_editable_mesh_brush_candidates():
		var editable_mesh_candidate_records: Array[Dictionary] = resolve_editable_mesh_brush_candidate_records_for_sphere(
			hit_point_local,
			radius_meters,
			preferred_face_id
		)
		if not editable_mesh_candidate_records.is_empty():
			return editable_mesh_candidate_records
	if not has_current_shell():
		return []
	var cell_size_meters: float = maxf(cell_world_size_meters, 0.0001)
	var radius_cells: float = radius_meters / cell_size_meters
	if radius_cells <= 0.0:
		return []
	var candidate_face_ids: PackedStringArray = resolve_shell_face_ids_for_brush_sphere(
		hit_point_local,
		radius_meters,
		preferred_face_id
	)
	if candidate_face_ids.is_empty():
		return []
	var patch_state_lookup_by_grid_key: Dictionary = _build_patch_state_lookup_by_shell_grid_key()
	var candidate_patch_records: Array[Dictionary] = []
	for face_id_string: String in candidate_face_ids:
		var shell_quad_id: StringName = StringName(face_id_string)
		var shell_quad_state: Resource = get_current_shell_quad_state_by_id(shell_quad_id)
		if shell_quad_state == null:
			continue
		_ensure_shell_quad_patch_offset_storage(
			shell_quad_state,
			_build_patch_states_by_shell_quad_id().get(shell_quad_id, [])
		)
		var width_steps: int = maxi(shell_quad_state.width_voxels, 1)
		var height_steps: int = maxi(shell_quad_state.height_voxels, 1)
		for v_index: int in range(height_steps):
			for u_index: int in range(width_steps):
				var patch_grid_key: StringName = _build_shell_patch_grid_key(shell_quad_id, u_index, v_index)
				var patch_state: Resource = patch_state_lookup_by_grid_key.get(patch_grid_key, null)
				if patch_state == null:
					continue
				var shell_patch_surface_quad = _build_current_shell_patch_surface_quad(shell_quad_state, u_index, v_index)
				if shell_patch_surface_quad == null:
					continue
				var patch_distance_cells: float = _distance_point_to_surface_quad(hit_point_local, shell_patch_surface_quad)
				if patch_distance_cells > radius_cells:
					continue
				candidate_patch_records.append({
					"patch_id": patch_state.patch_id,
					"patch_state": patch_state,
					"shell_quad_id": shell_quad_id,
					"grid_u_index": u_index,
					"grid_v_index": v_index,
					"distance_cells": patch_distance_cells,
					"surface_center_local": _resolve_surface_quad_center_local(shell_patch_surface_quad),
					"surface_normal": shell_patch_surface_quad.normal.normalized(),
				})
	return candidate_patch_records

func resolve_editable_mesh_brush_candidate_records_for_sphere(
	hit_point_local: Vector3,
	radius_meters: float,
	preferred_face_id: StringName = StringName()
) -> Array[Dictionary]:
	if not has_current_editable_mesh() or current_editable_mesh_state == null:
		return []
	var cell_size_meters: float = maxf(cell_world_size_meters, 0.0001)
	var radius_cells: float = radius_meters / cell_size_meters
	if radius_cells <= 0.0:
		return []
	var surface_arrays: Array = current_editable_mesh_state.get("surface_arrays") as Array
	if surface_arrays.size() <= Mesh.ARRAY_VERTEX or surface_arrays[Mesh.ARRAY_VERTEX] is not PackedVector3Array:
		return []
	var vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return []
	var normals: PackedVector3Array = PackedVector3Array()
	if surface_arrays.size() > Mesh.ARRAY_NORMAL and surface_arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
		normals = surface_arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = PackedInt32Array()
	if surface_arrays.size() > Mesh.ARRAY_INDEX and surface_arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		indices = surface_arrays[Mesh.ARRAY_INDEX]
	var triangle_patch_keys: PackedStringArray = PackedStringArray(current_editable_mesh_state.get("triangle_patch_keys"))
	var patch_state_lookup_by_grid_key: Dictionary = _build_patch_state_lookup_by_shell_grid_key()
	var candidate_record_lookup: Dictionary = {}
	if indices.is_empty():
		var triangle_index: int = 0
		for vertex_index: int in range(0, vertices.size() - 2, 3):
			_collect_editable_mesh_triangle_candidate_record(
				candidate_record_lookup,
				hit_point_local,
				radius_cells,
				vertices,
				normals,
				vertex_index,
				vertex_index + 1,
				vertex_index + 2,
				triangle_index,
				triangle_patch_keys,
				patch_state_lookup_by_grid_key,
				preferred_face_id
			)
			triangle_index += 1
	else:
		var triangle_index: int = 0
		for index_offset: int in range(0, indices.size() - 2, 3):
			var triangle_index_a: int = indices[index_offset]
			var triangle_index_b: int = indices[index_offset + 1]
			var triangle_index_c: int = indices[index_offset + 2]
			if (
				triangle_index_a < 0 or triangle_index_a >= vertices.size()
				or triangle_index_b < 0 or triangle_index_b >= vertices.size()
				or triangle_index_c < 0 or triangle_index_c >= vertices.size()
			):
				continue
			_collect_editable_mesh_triangle_candidate_record(
				candidate_record_lookup,
				hit_point_local,
				radius_cells,
				vertices,
				normals,
				triangle_index_a,
				triangle_index_b,
				triangle_index_c,
				triangle_index,
				triangle_patch_keys,
				patch_state_lookup_by_grid_key,
				preferred_face_id
			)
			triangle_index += 1
	var candidate_patch_records: Array[Dictionary] = []
	for candidate_patch_record in candidate_record_lookup.values():
		candidate_patch_records.append(candidate_patch_record)
	candidate_patch_records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return float(left.get("distance_cells", INF)) < float(right.get("distance_cells", INF))
	)
	return candidate_patch_records

func resolve_editable_mesh_vertex_indices_for_patch_ids(target_patch_ids: PackedStringArray) -> PackedInt32Array:
	var selected_vertex_lookup: Dictionary = {}
	if target_patch_ids.is_empty() or not has_current_editable_mesh() or current_editable_mesh_state == null:
		return PackedInt32Array()
	var surface_arrays: Array = current_editable_mesh_state.get("surface_arrays") as Array
	if surface_arrays.size() <= Mesh.ARRAY_VERTEX or surface_arrays[Mesh.ARRAY_VERTEX] is not PackedVector3Array:
		return PackedInt32Array()
	var vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return PackedInt32Array()
	var triangle_patch_keys: PackedStringArray = PackedStringArray(current_editable_mesh_state.get("triangle_patch_keys"))
	if triangle_patch_keys.is_empty():
		return PackedInt32Array()
	var selected_patch_grid_keys: Dictionary = _build_selected_patch_grid_key_lookup(target_patch_ids)
	if selected_patch_grid_keys.is_empty():
		return PackedInt32Array()
	var indices: PackedInt32Array = PackedInt32Array()
	if surface_arrays.size() > Mesh.ARRAY_INDEX and surface_arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		indices = surface_arrays[Mesh.ARRAY_INDEX]
	var triangle_count: int = mini(
		triangle_patch_keys.size(),
		int(float(indices.size()) / 3.0) if not indices.is_empty() else int(float(vertices.size()) / 3.0)
	)
	for triangle_index: int in range(triangle_count):
		var triangle_patch_key: StringName = StringName(triangle_patch_keys[triangle_index])
		if triangle_patch_key == StringName() or not selected_patch_grid_keys.has(triangle_patch_key):
			continue
		if indices.is_empty():
			var vertex_start_index: int = triangle_index * 3
			for vertex_index: int in [vertex_start_index, vertex_start_index + 1, vertex_start_index + 2]:
				if vertex_index < 0 or vertex_index >= vertices.size():
					continue
				selected_vertex_lookup[vertex_index] = true
			continue
		var index_start: int = triangle_index * 3
		for vertex_slot: int in range(3):
			var indexed_vertex: int = int(indices[index_start + vertex_slot])
			if indexed_vertex < 0 or indexed_vertex >= vertices.size():
				continue
			selected_vertex_lookup[indexed_vertex] = true
	var resolved_vertex_indices: PackedInt32Array = PackedInt32Array()
	var sorted_vertex_indices: Array = selected_vertex_lookup.keys()
	sorted_vertex_indices.sort()
	for vertex_index_value in sorted_vertex_indices:
		resolved_vertex_indices.append(int(vertex_index_value))
	return resolved_vertex_indices

func resolve_editable_mesh_hit_target(
	triangle_index: int,
	hit_point_local: Vector3,
	preferred_face_id: StringName = StringName()
) -> Dictionary:
	if triangle_index < 0 or not has_current_editable_mesh() or current_editable_mesh_state == null:
		return {}
	var resolved_face_id: StringName = preferred_face_id
	var triangle_face_ids: PackedStringArray = PackedStringArray(current_editable_mesh_state.get("triangle_face_ids"))
	if triangle_index < triangle_face_ids.size():
		var metadata_face_id: StringName = StringName(triangle_face_ids[triangle_index])
		if metadata_face_id != StringName():
			resolved_face_id = metadata_face_id
	var patch_state_lookup_by_grid_key: Dictionary = _build_patch_state_lookup_by_shell_grid_key()
	var triangle_patch_keys: PackedStringArray = PackedStringArray(current_editable_mesh_state.get("triangle_patch_keys"))
	if triangle_index < triangle_patch_keys.size():
		var triangle_patch_key: StringName = StringName(triangle_patch_keys[triangle_index])
		if triangle_patch_key != StringName():
			var metadata_patch_state: Resource = patch_state_lookup_by_grid_key.get(triangle_patch_key, null)
			if (
				metadata_patch_state != null
				and (resolved_face_id == StringName() or metadata_patch_state.shell_quad_id == resolved_face_id)
			):
				return _build_editable_mesh_hit_target_dictionary(metadata_patch_state, resolved_face_id)
	var fallback_patch_state: Resource = _resolve_nearest_patch_state_for_point(hit_point_local, resolved_face_id)
	if fallback_patch_state == null and resolved_face_id != preferred_face_id:
		fallback_patch_state = _resolve_nearest_patch_state_for_point(hit_point_local, preferred_face_id)
	return _build_editable_mesh_hit_target_dictionary(fallback_patch_state, resolved_face_id)

func has_editable_mesh_delta_for_patch_ids(target_patch_ids: PackedStringArray = PackedStringArray()) -> bool:
	if (
		not has_current_editable_mesh()
		or current_editable_mesh_state == null
		or baseline_editable_mesh_state == null
	):
		return false
	var current_surface_arrays: Array = current_editable_mesh_state.get("surface_arrays") as Array
	var baseline_surface_arrays: Array = baseline_editable_mesh_state.get("surface_arrays") as Array
	if (
		current_surface_arrays.size() <= Mesh.ARRAY_VERTEX
		or baseline_surface_arrays.size() <= Mesh.ARRAY_VERTEX
		or current_surface_arrays[Mesh.ARRAY_VERTEX] is not PackedVector3Array
		or baseline_surface_arrays[Mesh.ARRAY_VERTEX] is not PackedVector3Array
	):
		return false
	var current_vertices: PackedVector3Array = current_surface_arrays[Mesh.ARRAY_VERTEX]
	var baseline_vertices: PackedVector3Array = baseline_surface_arrays[Mesh.ARRAY_VERTEX]
	if current_vertices.size() != baseline_vertices.size() or current_vertices.is_empty():
		return false
	if target_patch_ids.is_empty():
		for vertex_index: int in range(current_vertices.size()):
			if not current_vertices[vertex_index].is_equal_approx(baseline_vertices[vertex_index]):
				return true
		return false
	var selected_vertex_indices: PackedInt32Array = resolve_editable_mesh_vertex_indices_for_patch_ids(target_patch_ids)
	if selected_vertex_indices.is_empty():
		return false
	for vertex_index: int in selected_vertex_indices:
		if vertex_index < 0 or vertex_index >= current_vertices.size():
			continue
		if not current_vertices[vertex_index].is_equal_approx(baseline_vertices[vertex_index]):
			return true
	return false

func _collect_editable_mesh_triangle_candidate_record(
	candidate_record_lookup: Dictionary,
	hit_point_local: Vector3,
	radius_cells: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	vertex_index_a: int,
	vertex_index_b: int,
	vertex_index_c: int,
	triangle_index: int,
	triangle_patch_keys: PackedStringArray,
	patch_state_lookup_by_grid_key: Dictionary,
	preferred_face_id: StringName
) -> void:
	var vertex_a: Vector3 = vertices[vertex_index_a]
	var vertex_b: Vector3 = vertices[vertex_index_b]
	var vertex_c: Vector3 = vertices[vertex_index_c]
	var surface_center_local: Vector3 = (vertex_a + vertex_b + vertex_c) / 3.0
	var distance_cells: float = surface_center_local.distance_to(hit_point_local)
	if distance_cells > radius_cells:
		return
	var patch_state: Resource = _resolve_patch_state_for_editable_mesh_triangle(
		triangle_index,
		triangle_patch_keys,
		patch_state_lookup_by_grid_key,
		surface_center_local,
		preferred_face_id
	)
	if patch_state == null:
		return
	var surface_normal: Vector3 = Vector3.ZERO
	if normals.size() == vertices.size():
		surface_normal = (
			normals[vertex_index_a]
			+ normals[vertex_index_b]
			+ normals[vertex_index_c]
		).normalized()
	if surface_normal == Vector3.ZERO:
		surface_normal = (vertex_b - vertex_a).cross(vertex_c - vertex_a).normalized()
	if surface_normal == Vector3.ZERO:
		return
	var existing_record: Dictionary = candidate_record_lookup.get(patch_state.patch_id, {})
	if not existing_record.is_empty() and float(existing_record.get("distance_cells", INF)) <= distance_cells:
		return
	candidate_record_lookup[patch_state.patch_id] = {
		"patch_id": patch_state.patch_id,
		"patch_state": patch_state,
		"shell_quad_id": patch_state.shell_quad_id,
		"grid_u_index": int(patch_state.get("grid_u_index")),
		"grid_v_index": int(patch_state.get("grid_v_index")),
		"distance_cells": distance_cells,
		"surface_center_local": surface_center_local,
		"surface_normal": surface_normal,
	}

func _resolve_patch_state_for_editable_mesh_triangle(
	triangle_index: int,
	triangle_patch_keys: PackedStringArray,
	patch_state_lookup_by_grid_key: Dictionary,
	surface_center_local: Vector3,
	preferred_face_id: StringName
) -> Resource:
	if triangle_index >= 0 and triangle_index < triangle_patch_keys.size():
		var triangle_patch_key: StringName = StringName(triangle_patch_keys[triangle_index])
		if triangle_patch_key != StringName():
			var metadata_patch_state: Resource = patch_state_lookup_by_grid_key.get(triangle_patch_key, null)
			if (
				metadata_patch_state != null
				and (preferred_face_id == StringName() or metadata_patch_state.shell_quad_id == preferred_face_id)
			):
				return metadata_patch_state
	return _resolve_nearest_patch_state_for_point(surface_center_local, preferred_face_id)

func _resolve_nearest_patch_state_for_point(point_local: Vector3, preferred_face_id: StringName = StringName()) -> Resource:
	var best_patch_state: Resource = null
	var best_patch_distance: float = INF
	for patch_state in patch_states:
		if patch_state == null:
			continue
		if preferred_face_id != StringName() and patch_state.shell_quad_id != preferred_face_id:
			continue
		var reference_quad: Resource = patch_state.current_quad if patch_state.current_quad != null else patch_state.baseline_quad
		if reference_quad == null:
			continue
		var patch_center_local: Vector3 = _resolve_surface_quad_center_local(reference_quad.build_canonical_surface_quad())
		var patch_distance: float = patch_center_local.distance_to(point_local)
		if patch_distance >= best_patch_distance:
			continue
		best_patch_distance = patch_distance
		best_patch_state = patch_state
	return best_patch_state

func _build_editable_mesh_hit_target_dictionary(
	patch_state: Resource,
	fallback_face_id: StringName = StringName()
) -> Dictionary:
	var resolved_face_id: StringName = fallback_face_id
	if patch_state != null and patch_state.shell_quad_id != StringName():
		resolved_face_id = patch_state.shell_quad_id
	return {
		"patch_state": patch_state,
		"patch_id": patch_state.patch_id if patch_state != null else StringName(),
		"zone_mask_id": patch_state.zone_mask_id if patch_state != null else StringName(),
		"face_id": resolved_face_id,
	}

func _should_use_editable_mesh_brush_candidates() -> bool:
	return (
		editable_mesh_visual_authority
		and has_current_editable_mesh()
		and current_editable_mesh_state != null
		and bool(current_editable_mesh_state.get("dirty"))
	)

func resolve_patch_distance_cells_for_brush_sphere(
	hit_point_local: Vector3,
	radius_meters: float,
	preferred_face_id: StringName = StringName()
) -> Dictionary:
	var patch_distance_lookup: Dictionary = {}
	for candidate_patch_record: Dictionary in resolve_shell_brush_candidate_records_for_sphere(
		hit_point_local,
		radius_meters,
		preferred_face_id
	):
		var patch_id: StringName = StringName(candidate_patch_record.get("patch_id", StringName()))
		if patch_id == StringName():
			continue
		patch_distance_lookup[String(patch_id)] = float(candidate_patch_record.get("distance_cells", INF))
	return patch_distance_lookup

func get_current_shell_quad_state_by_id(shell_quad_id: StringName) -> Resource:
	if current_shell_mesh_state == null or shell_quad_id == StringName():
		return null
	for shell_quad_state in current_shell_mesh_state.shell_quads:
		if shell_quad_state == null:
			continue
		if shell_quad_state.shell_quad_id == shell_quad_id:
			return shell_quad_state
	return null

func _build_patch_state_lookup_by_shell_grid_key() -> Dictionary:
	var patch_state_lookup: Dictionary = {}
	for patch_state in patch_states:
		if patch_state == null or patch_state.shell_quad_id == StringName():
			continue
		var patch_grid_key: StringName = _build_shell_patch_grid_key(
			patch_state.shell_quad_id,
			int(patch_state.get("grid_u_index")),
			int(patch_state.get("grid_v_index"))
		)
		patch_state_lookup[patch_grid_key] = patch_state
	return patch_state_lookup

func _build_selected_patch_grid_key_lookup(target_patch_ids: PackedStringArray) -> Dictionary:
	var selected_patch_grid_keys: Dictionary = {}
	if target_patch_ids.is_empty():
		return selected_patch_grid_keys
	var selected_patch_lookup: Dictionary = {}
	for patch_id: String in target_patch_ids:
		selected_patch_lookup[StringName(patch_id)] = true
	for patch_state in patch_states:
		if (
			patch_state == null
			or patch_state.shell_quad_id == StringName()
			or not selected_patch_lookup.has(patch_state.patch_id)
		):
			continue
		selected_patch_grid_keys[_build_shell_patch_grid_key(
			patch_state.shell_quad_id,
			int(patch_state.get("grid_u_index")),
			int(patch_state.get("grid_v_index"))
		)] = true
	return selected_patch_grid_keys

func sync_patch_states_from_current_editable_mesh() -> bool:
	if (
		not has_current_editable_mesh()
		or current_editable_mesh_state == null
		or baseline_editable_mesh_state == null
	):
		return false
	var current_surface_arrays: Array = current_editable_mesh_state.get("surface_arrays") as Array
	var baseline_surface_arrays: Array = baseline_editable_mesh_state.get("surface_arrays") as Array
	if (
		current_surface_arrays.size() <= Mesh.ARRAY_VERTEX
		or baseline_surface_arrays.size() <= Mesh.ARRAY_VERTEX
		or current_surface_arrays[Mesh.ARRAY_VERTEX] is not PackedVector3Array
		or baseline_surface_arrays[Mesh.ARRAY_VERTEX] is not PackedVector3Array
	):
		return false
	var current_vertices: PackedVector3Array = current_surface_arrays[Mesh.ARRAY_VERTEX]
	var baseline_vertices: PackedVector3Array = baseline_surface_arrays[Mesh.ARRAY_VERTEX]
	if current_vertices.size() != baseline_vertices.size() or current_vertices.is_empty():
		return false
	var triangle_patch_keys: PackedStringArray = PackedStringArray(current_editable_mesh_state.get("triangle_patch_keys"))
	if triangle_patch_keys.is_empty():
		return false
	var indices: PackedInt32Array = PackedInt32Array()
	if current_surface_arrays.size() > Mesh.ARRAY_INDEX and current_surface_arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		indices = current_surface_arrays[Mesh.ARRAY_INDEX]
	var patch_lookup_by_grid_key: Dictionary = _build_patch_state_lookup_by_shell_grid_key()
	var patch_offset_sum_lookup: Dictionary = {}
	var patch_offset_count_lookup: Dictionary = {}
	var triangle_count: int = mini(
		triangle_patch_keys.size(),
		int(float(indices.size()) / 3.0) if not indices.is_empty() else int(float(current_vertices.size()) / 3.0)
	)
	for triangle_index: int in range(triangle_count):
		var triangle_patch_key: StringName = StringName(triangle_patch_keys[triangle_index])
		if triangle_patch_key == StringName():
			continue
		var patch_state: Resource = patch_lookup_by_grid_key.get(triangle_patch_key, null)
		if patch_state == null or patch_state.baseline_quad == null or patch_state.current_quad == null:
			continue
		var patch_normal: Vector3 = patch_state.baseline_quad.normal.normalized()
		if patch_normal == Vector3.ZERO:
			continue
		if indices.is_empty():
			var vertex_start_index: int = triangle_index * 3
			for vertex_index: int in [vertex_start_index, vertex_start_index + 1, vertex_start_index + 2]:
				if vertex_index < 0 or vertex_index >= current_vertices.size():
					continue
				var offset_delta_cells: float = (baseline_vertices[vertex_index] - current_vertices[vertex_index]).dot(patch_normal)
				patch_offset_sum_lookup[triangle_patch_key] = float(patch_offset_sum_lookup.get(triangle_patch_key, 0.0)) + offset_delta_cells
				patch_offset_count_lookup[triangle_patch_key] = int(patch_offset_count_lookup.get(triangle_patch_key, 0)) + 1
			continue
		var index_start: int = triangle_index * 3
		for vertex_slot: int in range(3):
			var indexed_vertex: int = int(indices[index_start + vertex_slot])
			if indexed_vertex < 0 or indexed_vertex >= current_vertices.size():
				continue
			var offset_delta_cells: float = (baseline_vertices[indexed_vertex] - current_vertices[indexed_vertex]).dot(patch_normal)
			patch_offset_sum_lookup[triangle_patch_key] = float(patch_offset_sum_lookup.get(triangle_patch_key, 0.0)) + offset_delta_cells
			patch_offset_count_lookup[triangle_patch_key] = int(patch_offset_count_lookup.get(triangle_patch_key, 0)) + 1
	var offsets_changed: bool = false
	for patch_state in patch_states:
		if patch_state == null or patch_state.shell_quad_id == StringName():
			continue
		var patch_grid_key: StringName = _build_shell_patch_grid_key(
			patch_state.shell_quad_id,
			int(patch_state.get("grid_u_index")),
			int(patch_state.get("grid_v_index"))
		)
		var patch_sample_count: int = int(patch_offset_count_lookup.get(patch_grid_key, 0))
		if patch_sample_count <= 0:
			continue
		var next_offset_cells: float = float(patch_offset_sum_lookup.get(patch_grid_key, 0.0)) / float(patch_sample_count)
		if not is_equal_approx(float(patch_state.current_offset_cells), next_offset_cells):
			offsets_changed = true
		patch_state.current_offset_cells = next_offset_cells
		_sync_patch_current_quad_from_offset_cells(patch_state, next_offset_cells)
		patch_state.dirty = true
	return offsets_changed

func _build_shell_patch_grid_key(shell_quad_id: StringName, u_index: int, v_index: int) -> StringName:
	return StringName("%s::%d::%d" % [String(shell_quad_id), u_index, v_index])

func _build_current_shell_patch_surface_quad(shell_quad_state: Resource, u_index: int, v_index: int):
	if shell_quad_state == null:
		return null
	_ensure_shell_quad_vertex_offset_storage(shell_quad_state)
	var width_steps: int = maxi(shell_quad_state.width_voxels, 1)
	var height_steps: int = maxi(shell_quad_state.height_voxels, 1)
	var edge_u_step: Vector3 = shell_quad_state.edge_u_local / float(width_steps)
	var edge_v_step: Vector3 = shell_quad_state.edge_v_local / float(height_steps)
	if _resolve_shell_quad_patch_offset_index(shell_quad_state, u_index, v_index) < 0:
		return null
	var vertex_a: Vector3 = _resolve_shell_vertex_local(shell_quad_state, u_index, v_index, edge_u_step, edge_v_step)
	var vertex_b: Vector3 = _resolve_shell_vertex_local(shell_quad_state, u_index, v_index + 1, edge_u_step, edge_v_step)
	var vertex_c: Vector3 = _resolve_shell_vertex_local(shell_quad_state, u_index + 1, v_index + 1, edge_u_step, edge_v_step)
	var vertex_d: Vector3 = _resolve_shell_vertex_local(shell_quad_state, u_index + 1, v_index, edge_u_step, edge_v_step)
	var triangle_normal_a: Vector3 = (vertex_b - vertex_a).cross(vertex_c - vertex_a).normalized()
	var triangle_normal_b: Vector3 = (vertex_c - vertex_a).cross(vertex_d - vertex_a).normalized()
	var resolved_normal: Vector3 = (triangle_normal_a + triangle_normal_b).normalized()
	if resolved_normal == Vector3.ZERO:
		resolved_normal = shell_quad_state.normal
	var surface_quad = CraftedItemCanonicalSurfaceQuadScript.new()
	surface_quad.origin_local = vertex_a
	surface_quad.edge_u_local = vertex_d - vertex_a
	surface_quad.edge_v_local = vertex_b - vertex_a
	surface_quad.normal = resolved_normal
	surface_quad.material_variant_id = shell_quad_state.material_variant_id
	surface_quad.width_voxels = 1
	surface_quad.height_voxels = 1
	surface_quad.stage2_face_id = shell_quad_state.shell_quad_id
	surface_quad.stage2_shell_quad_id = shell_quad_state.shell_quad_id
	return surface_quad

func _distance_point_to_shell_quad(point_local: Vector3, shell_quad_state: Resource) -> float:
	if shell_quad_state == null:
		return INF
	return _distance_point_to_surface_quad(point_local, shell_quad_state)

func _resolve_surface_quad_center_local(surface_quad) -> Vector3:
	if surface_quad == null:
		return Vector3.ZERO
	return (
		surface_quad.origin_local
		+ (surface_quad.edge_u_local * 0.5)
		+ (surface_quad.edge_v_local * 0.5)
	)

func _distance_point_to_surface_quad(point_local: Vector3, quad_state) -> float:
	if quad_state == null:
		return INF
	var origin_local: Vector3 = quad_state.origin_local
	var edge_u_local: Vector3 = quad_state.edge_u_local
	var edge_v_local: Vector3 = quad_state.edge_v_local
	var relative_point: Vector3 = point_local - origin_local
	var edge_u_length_squared: float = edge_u_local.length_squared()
	var edge_v_length_squared: float = edge_v_local.length_squared()
	var u_ratio: float = 0.0
	var v_ratio: float = 0.0
	if edge_u_length_squared > 0.000001:
		u_ratio = clampf(relative_point.dot(edge_u_local) / edge_u_length_squared, 0.0, 1.0)
	if edge_v_length_squared > 0.000001:
		v_ratio = clampf(relative_point.dot(edge_v_local) / edge_v_length_squared, 0.0, 1.0)
	var closest_point: Vector3 = origin_local + (edge_u_local * u_ratio) + (edge_v_local * v_ratio)
	return point_local.distance_to(closest_point)

func resolve_patch_ids_for_shell_edge_ids(shell_edge_ids: PackedStringArray) -> PackedStringArray:
	if shell_edge_ids.is_empty():
		return PackedStringArray()
	var patch_states_by_shell_quad_id: Dictionary = _build_patch_states_by_shell_quad_id()
	var unique_patch_lookup: Dictionary = {}
	var patch_ids: PackedStringArray = PackedStringArray()
	for shell_edge_id_string: String in shell_edge_ids:
		var shell_edge_parts: Dictionary = _parse_shell_edge_id(StringName(shell_edge_id_string))
		var shell_quad_id: StringName = shell_edge_parts.get("shell_quad_id", StringName())
		var boundary_edge_id: StringName = shell_edge_parts.get("boundary_edge_id", StringName())
		if shell_quad_id == StringName() or boundary_edge_id == StringName():
			continue
		var shell_quad_state: Resource = get_current_shell_quad_state_by_id(shell_quad_id)
		if shell_quad_state == null:
			continue
		var shell_patch_states: Array = patch_states_by_shell_quad_id.get(shell_quad_id, [])
		if shell_patch_states.is_empty():
			continue
		var full_width_steps: int = maxi(shell_quad_state.width_voxels, 1)
		var full_height_steps: int = maxi(shell_quad_state.height_voxels, 1)
		var edge_u_step: Vector3 = shell_quad_state.edge_u_local / float(full_width_steps)
		var edge_v_step: Vector3 = shell_quad_state.edge_v_local / float(full_height_steps)
		for patch_state in shell_patch_states:
			if patch_state == null or patch_state.baseline_quad == null:
				continue
			var patch_grid_coords: Vector2i = _resolve_patch_grid_coords(shell_quad_state, patch_state, edge_u_step, edge_v_step)
			var is_boundary_patch: bool = false
			match boundary_edge_id:
				&"edge_u_min":
					is_boundary_patch = patch_grid_coords.x == 0
				&"edge_u_max":
					is_boundary_patch = patch_grid_coords.x == full_width_steps - 1
				&"edge_v_min":
					is_boundary_patch = patch_grid_coords.y == 0
				&"edge_v_max":
					is_boundary_patch = patch_grid_coords.y == full_height_steps - 1
				_:
					is_boundary_patch = false
			if not is_boundary_patch:
				continue
			if unique_patch_lookup.has(patch_state.patch_id):
				continue
			unique_patch_lookup[patch_state.patch_id] = true
			patch_ids.append(String(patch_state.patch_id))
	return patch_ids

func resolve_patch_ids_for_shell_feature_edge_ids(shell_feature_edge_ids: PackedStringArray) -> PackedStringArray:
	if shell_feature_edge_ids.is_empty():
		return PackedStringArray()
	var patch_states_by_shell_quad_id: Dictionary = _build_patch_states_by_shell_quad_id()
	var unique_patch_lookup: Dictionary = {}
	var patch_ids: PackedStringArray = PackedStringArray()
	for shell_feature_edge_id_string: String in shell_feature_edge_ids:
		var shell_feature_edge_parts: Dictionary = _parse_shell_feature_edge_id(StringName(shell_feature_edge_id_string))
		var shell_quad_id: StringName = shell_feature_edge_parts.get("shell_quad_id", StringName())
		var orientation: StringName = shell_feature_edge_parts.get("orientation", StringName())
		var split_index: int = int(shell_feature_edge_parts.get("split_index", -1))
		if shell_quad_id == StringName() or orientation == StringName() or split_index <= 0:
			continue
		var shell_quad_state: Resource = get_current_shell_quad_state_by_id(shell_quad_id)
		if shell_quad_state == null:
			continue
		var shell_patch_states: Array = patch_states_by_shell_quad_id.get(shell_quad_id, [])
		if shell_patch_states.is_empty():
			continue
		var full_width_steps: int = maxi(shell_quad_state.width_voxels, 1)
		var full_height_steps: int = maxi(shell_quad_state.height_voxels, 1)
		var edge_u_step: Vector3 = shell_quad_state.edge_u_local / float(full_width_steps)
		var edge_v_step: Vector3 = shell_quad_state.edge_v_local / float(full_height_steps)
		for patch_state in shell_patch_states:
			if patch_state == null or patch_state.baseline_quad == null:
				continue
			var patch_grid_coords: Vector2i = _resolve_patch_grid_coords(shell_quad_state, patch_state, edge_u_step, edge_v_step)
			var include_patch: bool = false
			match orientation:
				&"feature_u":
					include_patch = patch_grid_coords.x == split_index - 1 or patch_grid_coords.x == split_index
				&"feature_v":
					include_patch = patch_grid_coords.y == split_index - 1 or patch_grid_coords.y == split_index
				_:
					include_patch = false
			if not include_patch:
				continue
			if unique_patch_lookup.has(patch_state.patch_id):
				continue
			unique_patch_lookup[patch_state.patch_id] = true
			patch_ids.append(String(patch_state.patch_id))
	return patch_ids

func resolve_patch_ids_for_shell_feature_region_ids(shell_feature_region_ids: PackedStringArray) -> PackedStringArray:
	if shell_feature_region_ids.is_empty():
		return PackedStringArray()
	var unique_patch_lookup: Dictionary = {}
	var patch_ids: PackedStringArray = PackedStringArray()
	for shell_feature_region_id_string: String in shell_feature_region_ids:
		var shell_feature_region_parts: Dictionary = _parse_shell_feature_region_id(StringName(shell_feature_region_id_string))
		var shell_quad_id: StringName = shell_feature_region_parts.get("shell_quad_id", StringName())
		var anchor_patch_id: StringName = shell_feature_region_parts.get("anchor_patch_id", StringName())
		if shell_quad_id == StringName() or anchor_patch_id == StringName():
			continue
		var anchor_patch_state: Resource = null
		for patch_state in patch_states:
			if patch_state == null:
				continue
			if patch_state.patch_id == anchor_patch_id:
				anchor_patch_state = patch_state
				break
		if anchor_patch_state == null or anchor_patch_state.shell_quad_id != shell_quad_id:
			continue
		var region_patch_ids: PackedStringArray = _resolve_connected_offset_feature_region_patch_ids_from_anchor(anchor_patch_state)
		for patch_id: String in region_patch_ids:
			if unique_patch_lookup.has(StringName(patch_id)):
				continue
			unique_patch_lookup[StringName(patch_id)] = true
			patch_ids.append(patch_id)
	return patch_ids

func resolve_patch_ids_for_shell_feature_band_ids(shell_feature_band_ids: PackedStringArray) -> PackedStringArray:
	if shell_feature_band_ids.is_empty():
		return PackedStringArray()
	var unique_patch_lookup: Dictionary = {}
	var patch_ids: PackedStringArray = PackedStringArray()
	for shell_feature_band_id_string: String in shell_feature_band_ids:
		var shell_feature_band_parts: Dictionary = _parse_shell_feature_band_id(StringName(shell_feature_band_id_string))
		var shell_quad_id: StringName = shell_feature_band_parts.get("shell_quad_id", StringName())
		var anchor_patch_id: StringName = shell_feature_band_parts.get("anchor_patch_id", StringName())
		if shell_quad_id == StringName() or anchor_patch_id == StringName():
			continue
		var anchor_patch_state: Resource = _find_patch_state_by_id(anchor_patch_id)
		if anchor_patch_state == null or anchor_patch_state.shell_quad_id != shell_quad_id:
			continue
		var band_patch_ids: PackedStringArray = resolve_feature_band_patch_ids_from_patch_id(anchor_patch_id)
		for patch_id: String in band_patch_ids:
			var patch_id_name: StringName = StringName(patch_id)
			if unique_patch_lookup.has(patch_id_name):
				continue
			unique_patch_lookup[patch_id_name] = true
			patch_ids.append(patch_id)
	return patch_ids

func resolve_patch_ids_for_shell_feature_cluster_ids(shell_feature_cluster_ids: PackedStringArray) -> PackedStringArray:
	if shell_feature_cluster_ids.is_empty():
		return PackedStringArray()
	var unique_patch_lookup: Dictionary = {}
	var patch_ids: PackedStringArray = PackedStringArray()
	for shell_feature_cluster_id_string: String in shell_feature_cluster_ids:
		var shell_feature_cluster_parts: Dictionary = _parse_shell_feature_cluster_id(StringName(shell_feature_cluster_id_string))
		var shell_quad_id: StringName = shell_feature_cluster_parts.get("shell_quad_id", StringName())
		var anchor_patch_id: StringName = shell_feature_cluster_parts.get("anchor_patch_id", StringName())
		if shell_quad_id == StringName() or anchor_patch_id == StringName():
			continue
		var anchor_patch_state: Resource = _find_patch_state_by_id(anchor_patch_id)
		if anchor_patch_state == null or anchor_patch_state.shell_quad_id != shell_quad_id:
			continue
		var cluster_patch_ids: PackedStringArray = resolve_feature_cluster_patch_ids_from_patch_id(anchor_patch_id)
		for patch_id: String in cluster_patch_ids:
			var patch_id_name: StringName = StringName(patch_id)
			if unique_patch_lookup.has(patch_id_name):
				continue
			unique_patch_lookup[patch_id_name] = true
			patch_ids.append(patch_id)
	return patch_ids

func resolve_patch_ids_for_shell_feature_bridge_ids(shell_feature_bridge_ids: PackedStringArray) -> PackedStringArray:
	if shell_feature_bridge_ids.is_empty():
		return PackedStringArray()
	var unique_patch_lookup: Dictionary = {}
	var patch_ids: PackedStringArray = PackedStringArray()
	for shell_feature_bridge_id_string: String in shell_feature_bridge_ids:
		var shell_feature_bridge_parts: Dictionary = _parse_shell_feature_bridge_id(StringName(shell_feature_bridge_id_string))
		var shell_quad_id: StringName = shell_feature_bridge_parts.get("shell_quad_id", StringName())
		var anchor_patch_id: StringName = shell_feature_bridge_parts.get("anchor_patch_id", StringName())
		if shell_quad_id == StringName() or anchor_patch_id == StringName():
			continue
		var anchor_patch_state: Resource = _find_patch_state_by_id(anchor_patch_id)
		if anchor_patch_state == null or anchor_patch_state.shell_quad_id != shell_quad_id:
			continue
		var bridge_patch_ids: PackedStringArray = resolve_feature_bridge_patch_ids_from_patch_id(anchor_patch_id)
		for patch_id: String in bridge_patch_ids:
			var patch_id_name: StringName = StringName(patch_id)
			if unique_patch_lookup.has(patch_id_name):
				continue
			unique_patch_lookup[patch_id_name] = true
			patch_ids.append(patch_id)
	return patch_ids

func resolve_patch_ids_for_shell_feature_contour_ids(shell_feature_contour_ids: PackedStringArray) -> PackedStringArray:
	if shell_feature_contour_ids.is_empty():
		return PackedStringArray()
	var unique_patch_lookup: Dictionary = {}
	var patch_ids: PackedStringArray = PackedStringArray()
	for shell_feature_contour_id_string: String in shell_feature_contour_ids:
		var shell_feature_contour_parts: Dictionary = _parse_shell_feature_contour_id(StringName(shell_feature_contour_id_string))
		var shell_quad_id: StringName = shell_feature_contour_parts.get("shell_quad_id", StringName())
		var anchor_patch_id: StringName = shell_feature_contour_parts.get("anchor_patch_id", StringName())
		if shell_quad_id == StringName() or anchor_patch_id == StringName():
			continue
		var anchor_patch_state: Resource = _find_patch_state_by_id(anchor_patch_id)
		if anchor_patch_state == null or anchor_patch_state.shell_quad_id != shell_quad_id:
			continue
		var contour_patch_ids: PackedStringArray = resolve_feature_contour_patch_ids_from_patch_id(anchor_patch_id)
		for patch_id: String in contour_patch_ids:
			var patch_id_name: StringName = StringName(patch_id)
			if unique_patch_lookup.has(patch_id_name):
				continue
			unique_patch_lookup[patch_id_name] = true
			patch_ids.append(patch_id)
	return patch_ids

func resolve_patch_ids_for_shell_feature_loop_ids(shell_feature_loop_ids: PackedStringArray) -> PackedStringArray:
	if shell_feature_loop_ids.is_empty():
		return PackedStringArray()
	var unique_patch_lookup: Dictionary = {}
	var patch_ids: PackedStringArray = PackedStringArray()
	for shell_feature_loop_id_string: String in shell_feature_loop_ids:
		var shell_feature_loop_parts: Dictionary = _parse_shell_feature_loop_id(StringName(shell_feature_loop_id_string))
		var shell_quad_id: StringName = shell_feature_loop_parts.get("shell_quad_id", StringName())
		var anchor_patch_id: StringName = shell_feature_loop_parts.get("anchor_patch_id", StringName())
		if shell_quad_id == StringName() or anchor_patch_id == StringName():
			continue
		var anchor_patch_state: Resource = _find_patch_state_by_id(anchor_patch_id)
		if anchor_patch_state == null or anchor_patch_state.shell_quad_id != shell_quad_id:
			continue
		var loop_patch_ids: PackedStringArray = resolve_feature_loop_patch_ids_from_patch_id(anchor_patch_id)
		for patch_id: String in loop_patch_ids:
			var patch_id_name: StringName = StringName(patch_id)
			if unique_patch_lookup.has(patch_id_name):
				continue
			unique_patch_lookup[patch_id_name] = true
			patch_ids.append(patch_id)
	return patch_ids

func _resolve_hover_patch_id_from_selection_hit(hit_data: Dictionary) -> StringName:
	if hit_data.is_empty():
		return StringName()
	return StringName(hit_data.get("patch_id", StringName()))

func _resolve_hover_face_id_from_selection_hit(hit_data: Dictionary) -> StringName:
	if hit_data.is_empty():
		return StringName()
	return StringName(hit_data.get("face_id", StringName()))

func _resolve_nearest_shell_boundary_edge_id(shell_face_id: StringName, hit_point_local: Variant) -> StringName:
	if shell_face_id == StringName() or hit_point_local is not Vector3:
		return StringName()
	var shell_quad_state: Resource = get_current_shell_quad_state_by_id(shell_face_id)
	if shell_quad_state == null:
		return StringName()
	var canonical_surface_quad = shell_quad_state.build_canonical_surface_quad()
	var best_edge_id: StringName = StringName()
	var best_distance: float = INF
	for boundary_edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
		var edge_segment: Dictionary = _build_edge_segment(canonical_surface_quad, boundary_edge_id)
		var edge_distance: float = _distance_point_to_segment(
			hit_point_local,
			edge_segment.get("start", Vector3.ZERO),
			edge_segment.get("end", Vector3.ZERO)
		)
		if edge_distance >= best_distance:
			continue
		best_distance = edge_distance
		best_edge_id = _build_shell_boundary_edge_identifier(shell_face_id, boundary_edge_id)
	return best_edge_id

func _build_shell_boundary_edge_identifier(shell_face_id: StringName, boundary_edge_id: StringName) -> StringName:
	if shell_face_id == StringName() or boundary_edge_id == StringName():
		return StringName()
	return StringName("%s::%s" % [String(shell_face_id), String(boundary_edge_id)])

func _resolve_nearest_shell_feature_edge_id(shell_face_id: StringName, hit_point_local: Variant) -> StringName:
	if shell_face_id == StringName() or hit_point_local is not Vector3:
		return StringName()
	var shell_quad_state: Resource = get_current_shell_quad_state_by_id(shell_face_id)
	if shell_quad_state == null:
		return StringName()
	var full_width_steps: int = maxi(shell_quad_state.width_voxels, 1)
	var full_height_steps: int = maxi(shell_quad_state.height_voxels, 1)
	if full_width_steps <= 1 and full_height_steps <= 1:
		return StringName()
	var edge_u_step: Vector3 = shell_quad_state.edge_u_local / float(full_width_steps)
	var edge_v_step: Vector3 = shell_quad_state.edge_v_local / float(full_height_steps)
	var best_edge_id: StringName = StringName()
	var best_distance: float = INF
	for split_u_index: int in range(1, full_width_steps):
		var edge_start: Vector3 = shell_quad_state.origin_local + (edge_u_step * float(split_u_index))
		var edge_end: Vector3 = edge_start + shell_quad_state.edge_v_local
		var edge_distance: float = _distance_point_to_segment(hit_point_local, edge_start, edge_end)
		if edge_distance >= best_distance:
			continue
		best_distance = edge_distance
		best_edge_id = _build_shell_feature_edge_identifier(shell_face_id, &"feature_u", split_u_index)
	for split_v_index: int in range(1, full_height_steps):
		var edge_start: Vector3 = shell_quad_state.origin_local + (edge_v_step * float(split_v_index))
		var edge_end: Vector3 = edge_start + shell_quad_state.edge_u_local
		var edge_distance: float = _distance_point_to_segment(hit_point_local, edge_start, edge_end)
		if edge_distance >= best_distance:
			continue
		best_distance = edge_distance
		best_edge_id = _build_shell_feature_edge_identifier(shell_face_id, &"feature_v", split_v_index)
	return best_edge_id

func _build_shell_feature_edge_identifier(shell_face_id: StringName, orientation: StringName, split_index: int) -> StringName:
	if shell_face_id == StringName() or orientation == StringName() or split_index <= 0:
		return StringName()
	return StringName("%s::%s::%d" % [String(shell_face_id), String(orientation), split_index])

func _build_shell_feature_region_identifier(shell_face_id: StringName, patch_ids: PackedStringArray) -> StringName:
	if shell_face_id == StringName() or patch_ids.is_empty():
		return StringName()
	var sorted_patch_ids: PackedStringArray = PackedStringArray(patch_ids)
	sorted_patch_ids.sort()
	return StringName("%s::region::%s" % [String(shell_face_id), sorted_patch_ids[0]])

func _build_shell_feature_band_identifier(shell_face_id: StringName, region_patch_ids: PackedStringArray) -> StringName:
	if shell_face_id == StringName() or region_patch_ids.is_empty():
		return StringName()
	var sorted_patch_ids: PackedStringArray = PackedStringArray(region_patch_ids)
	sorted_patch_ids.sort()
	return StringName("%s::band::%s" % [String(shell_face_id), sorted_patch_ids[0]])

func _build_shell_feature_cluster_identifier(shell_face_id: StringName, cluster_patch_ids: PackedStringArray) -> StringName:
	if shell_face_id == StringName() or cluster_patch_ids.is_empty():
		return StringName()
	var sorted_patch_ids: PackedStringArray = PackedStringArray(cluster_patch_ids)
	sorted_patch_ids.sort()
	return StringName("%s::cluster::%s" % [String(shell_face_id), sorted_patch_ids[0]])

func _build_shell_feature_bridge_identifier(shell_face_id: StringName, bridge_patch_ids: PackedStringArray) -> StringName:
	if shell_face_id == StringName() or bridge_patch_ids.is_empty():
		return StringName()
	var sorted_patch_ids: PackedStringArray = PackedStringArray(bridge_patch_ids)
	sorted_patch_ids.sort()
	return StringName("%s::bridge::%s" % [String(shell_face_id), sorted_patch_ids[0]])

func _build_shell_feature_contour_identifier(shell_face_id: StringName, contour_patch_ids: PackedStringArray) -> StringName:
	if shell_face_id == StringName() or contour_patch_ids.is_empty():
		return StringName()
	var sorted_patch_ids: PackedStringArray = PackedStringArray(contour_patch_ids)
	sorted_patch_ids.sort()
	return StringName("%s::contour::%s" % [String(shell_face_id), sorted_patch_ids[0]])

func _build_shell_feature_loop_identifier(shell_face_id: StringName, loop_patch_ids: PackedStringArray) -> StringName:
	if shell_face_id == StringName() or loop_patch_ids.is_empty():
		return StringName()
	var sorted_patch_ids: PackedStringArray = PackedStringArray(loop_patch_ids)
	sorted_patch_ids.sort()
	return StringName("%s::loop::%s" % [String(shell_face_id), sorted_patch_ids[0]])

func _is_surface_face_selection_tool(tool_id: StringName) -> bool:
	return String(tool_id).begins_with("stage2_surface_face_")

func _is_surface_edge_selection_tool(tool_id: StringName) -> bool:
	return String(tool_id).begins_with("stage2_surface_edge_")

func _is_surface_feature_edge_selection_tool(tool_id: StringName) -> bool:
	return String(tool_id).begins_with("stage2_surface_feature_edge_")

func _is_surface_feature_region_selection_tool(tool_id: StringName) -> bool:
	return String(tool_id).begins_with("stage2_surface_feature_region_")

func _is_surface_feature_band_selection_tool(tool_id: StringName) -> bool:
	return String(tool_id).begins_with("stage2_surface_feature_band_")

func _is_surface_feature_cluster_selection_tool(tool_id: StringName) -> bool:
	return String(tool_id).begins_with("stage2_surface_feature_cluster_")

func _is_surface_feature_bridge_selection_tool(tool_id: StringName) -> bool:
	return String(tool_id).begins_with("stage2_surface_feature_bridge_")

func _is_surface_feature_contour_selection_tool(tool_id: StringName) -> bool:
	return String(tool_id).begins_with("stage2_surface_feature_contour_")

func _is_surface_feature_loop_selection_tool(tool_id: StringName) -> bool:
	return String(tool_id).begins_with("stage2_surface_feature_loop_")

func _resolve_feature_loop_patch_ids_for_region(region_patch_ids: PackedStringArray) -> PackedStringArray:
	if region_patch_ids.is_empty():
		return PackedStringArray()
	var patch_lookup: Dictionary = _build_patch_lookup()
	var region_lookup: Dictionary = {}
	for patch_id: String in region_patch_ids:
		region_lookup[StringName(patch_id)] = true
	var loop_patch_ids: PackedStringArray = PackedStringArray()
	for patch_id: String in region_patch_ids:
		var patch_state: Resource = patch_lookup.get(StringName(patch_id), null)
		if patch_state == null or patch_state.current_quad == null:
			continue
		var adjacent_patch_ids: PackedStringArray = _resolve_boundary_neighbor_patch_ids(patch_state)
		for neighbor_patch_id_string: String in adjacent_patch_ids:
			var neighbor_patch_id: StringName = StringName(neighbor_patch_id_string)
			if region_lookup.has(neighbor_patch_id):
				continue
			var neighbor_patch_state: Resource = patch_lookup.get(neighbor_patch_id, null)
			if neighbor_patch_state == null or neighbor_patch_state.current_quad == null:
				continue
			if not _shares_topology_plane_and_normal(patch_state, neighbor_patch_state):
				continue
			if is_equal_approx(resolve_current_offset_cells(patch_state), resolve_current_offset_cells(neighbor_patch_state)):
				continue
			_append_unique_patch_id(loop_patch_ids, patch_id)
			_append_unique_patch_id(loop_patch_ids, String(neighbor_patch_id))
	if loop_patch_ids.is_empty():
		return PackedStringArray()
	return loop_patch_ids

func _resolve_feature_band_patch_ids_for_region(region_patch_ids: PackedStringArray) -> PackedStringArray:
	if region_patch_ids.is_empty():
		return PackedStringArray()
	var band_patch_ids: PackedStringArray = PackedStringArray(region_patch_ids)
	var loop_patch_ids: PackedStringArray = _resolve_feature_loop_patch_ids_for_region(region_patch_ids)
	for patch_id: String in loop_patch_ids:
		_append_unique_patch_id(band_patch_ids, patch_id)
	return band_patch_ids

func _resolve_feature_cluster_patch_ids_from_anchor(anchor_patch_state: Resource) -> PackedStringArray:
	if anchor_patch_state == null or anchor_patch_state.current_quad == null:
		return PackedStringArray()
	if is_zero_approx(resolve_current_offset_cells(anchor_patch_state)):
		return PackedStringArray()
	var patch_lookup: Dictionary = _build_patch_lookup()
	var cluster_patch_ids: PackedStringArray = PackedStringArray()
	var visited_region_anchor_lookup: Dictionary = {}
	var pending_region_anchor_ids: Array[StringName] = [anchor_patch_state.patch_id]
	while not pending_region_anchor_ids.is_empty():
		var region_anchor_id: StringName = pending_region_anchor_ids.pop_back()
		if region_anchor_id == StringName() or visited_region_anchor_lookup.has(region_anchor_id):
			continue
		var region_anchor_state: Resource = patch_lookup.get(region_anchor_id, null)
		if region_anchor_state == null or region_anchor_state.current_quad == null:
			continue
		if region_anchor_state.zone_mask_id != anchor_patch_state.zone_mask_id:
			continue
		if not _shares_topology_plane_and_normal(anchor_patch_state, region_anchor_state):
			continue
		if is_zero_approx(resolve_current_offset_cells(region_anchor_state)):
			continue
		visited_region_anchor_lookup[region_anchor_id] = true
		var region_patch_ids: PackedStringArray = _resolve_connected_offset_feature_region_patch_ids_from_anchor(region_anchor_state)
		if region_patch_ids.is_empty():
			continue
		var band_patch_ids: PackedStringArray = _resolve_feature_band_patch_ids_for_region(region_patch_ids)
		for patch_id: String in band_patch_ids:
			_append_unique_patch_id(cluster_patch_ids, patch_id)
		for patch_id: String in band_patch_ids:
			var patch_state: Resource = patch_lookup.get(StringName(patch_id), null)
			if patch_state == null or patch_state.current_quad == null:
				continue
			if patch_state.zone_mask_id != anchor_patch_state.zone_mask_id:
				continue
			if not _shares_topology_plane_and_normal(anchor_patch_state, patch_state):
				continue
			if is_zero_approx(resolve_current_offset_cells(patch_state)):
				continue
			if not visited_region_anchor_lookup.has(patch_state.patch_id):
				pending_region_anchor_ids.append(patch_state.patch_id)
	return cluster_patch_ids

func _resolve_feature_bridge_patch_ids_from_anchor(anchor_patch_state: Resource) -> PackedStringArray:
	if anchor_patch_state == null or anchor_patch_state.current_quad == null:
		return PackedStringArray()
	if is_zero_approx(resolve_current_offset_cells(anchor_patch_state)):
		return PackedStringArray()
	var patch_lookup: Dictionary = _build_patch_lookup()
	var bridge_patch_ids: PackedStringArray = PackedStringArray()
	var visited_cluster_seed_lookup: Dictionary = {}
	var pending_cluster_seed_ids: Array[StringName] = [anchor_patch_state.patch_id]
	while not pending_cluster_seed_ids.is_empty():
		var cluster_seed_id: StringName = pending_cluster_seed_ids.pop_back()
		if cluster_seed_id == StringName() or visited_cluster_seed_lookup.has(cluster_seed_id):
			continue
		var cluster_seed_state: Resource = patch_lookup.get(cluster_seed_id, null)
		if cluster_seed_state == null or cluster_seed_state.current_quad == null:
			continue
		if cluster_seed_state.zone_mask_id != anchor_patch_state.zone_mask_id:
			continue
		if is_zero_approx(resolve_current_offset_cells(cluster_seed_state)):
			continue
		visited_cluster_seed_lookup[cluster_seed_id] = true
		var cluster_patch_ids: PackedStringArray = _resolve_feature_cluster_patch_ids_from_anchor(cluster_seed_state)
		if cluster_patch_ids.is_empty():
			continue
		for patch_id: String in cluster_patch_ids:
			_append_unique_patch_id(bridge_patch_ids, patch_id)
		for patch_id: String in cluster_patch_ids:
			var patch_state: Resource = patch_lookup.get(StringName(patch_id), null)
			if patch_state == null or patch_state.current_quad == null:
				continue
			for bridge_neighbor_patch_id_string: String in _resolve_feature_bridge_neighbor_patch_ids(patch_state):
				var bridge_neighbor_patch_id: StringName = StringName(bridge_neighbor_patch_id_string)
				if not visited_cluster_seed_lookup.has(bridge_neighbor_patch_id):
					pending_cluster_seed_ids.append(bridge_neighbor_patch_id)
	return bridge_patch_ids

func _resolve_feature_contour_patch_ids_for_bridge(bridge_patch_ids: PackedStringArray) -> PackedStringArray:
	if bridge_patch_ids.is_empty():
		return PackedStringArray()
	var patch_lookup: Dictionary = _build_patch_lookup()
	var bridge_lookup: Dictionary = {}
	for patch_id: String in bridge_patch_ids:
		bridge_lookup[StringName(patch_id)] = true
	var contour_patch_ids: PackedStringArray = PackedStringArray()
	for patch_id: String in bridge_patch_ids:
		var patch_state: Resource = patch_lookup.get(StringName(patch_id), null)
		if patch_state == null or patch_state.current_quad == null:
			continue
		if _patch_has_feature_contour_transition(patch_lookup, patch_state, bridge_lookup):
			_append_unique_patch_id(contour_patch_ids, patch_id)
	if contour_patch_ids.is_empty():
		return PackedStringArray()
	return contour_patch_ids

func _build_current_canonical_geometry_internal(source_solid = null, patch_id_lookup: Dictionary = {}):
	var canonical_geometry = CraftedItemCanonicalGeometryScript.new()
	canonical_geometry.source_solid = source_solid
	canonical_geometry.local_aabb = AABB(current_local_aabb_position, current_local_aabb_size)
	if patch_states.is_empty():
		return canonical_geometry
	for patch_state in patch_states:
		if patch_state == null or not patch_state.has_current_quad():
			continue
		if not patch_id_lookup.is_empty() and not patch_id_lookup.has(patch_state.patch_id):
			continue
		canonical_geometry.surface_quads.append(patch_state.current_quad.build_canonical_surface_quad())
	return canonical_geometry

func _should_build_canonical_geometry_from_editable_mesh() -> bool:
	return (
		editable_mesh_visual_authority
		and has_current_editable_mesh()
		and current_editable_mesh_state != null
		and bool(current_editable_mesh_state.get("dirty"))
	)

func _build_current_canonical_geometry_from_editable_mesh(source_solid = null):
	var canonical_geometry = CraftedItemCanonicalGeometryScript.new()
	canonical_geometry.source_solid = source_solid
	if current_editable_mesh_state == null:
		canonical_geometry.local_aabb = AABB(current_local_aabb_position, current_local_aabb_size)
		return canonical_geometry
	var editable_mesh_position: Variant = current_editable_mesh_state.get("local_aabb_position")
	var editable_mesh_size: Variant = current_editable_mesh_state.get("local_aabb_size")
	if editable_mesh_position is Vector3 and editable_mesh_size is Vector3:
		canonical_geometry.local_aabb = AABB(editable_mesh_position, editable_mesh_size)
	else:
		canonical_geometry.local_aabb = AABB(current_local_aabb_position, current_local_aabb_size)
	var surface_arrays: Array = current_editable_mesh_state.get("surface_arrays") as Array
	if surface_arrays.size() <= Mesh.ARRAY_VERTEX or surface_arrays[Mesh.ARRAY_VERTEX] is not PackedVector3Array:
		return canonical_geometry
	var vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return canonical_geometry
	var normals: PackedVector3Array = PackedVector3Array()
	if surface_arrays.size() > Mesh.ARRAY_NORMAL and surface_arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
		normals = surface_arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = PackedInt32Array()
	if surface_arrays.size() > Mesh.ARRAY_INDEX and surface_arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		indices = surface_arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for vertex_index: int in range(0, vertices.size() - 2, 3):
			_append_editable_mesh_triangle_to_canonical_geometry(
				canonical_geometry,
				vertices,
				normals,
				vertex_index,
				vertex_index + 1,
				vertex_index + 2
			)
		return canonical_geometry
	for index_offset: int in range(0, indices.size() - 2, 3):
		var triangle_index_a: int = indices[index_offset]
		var triangle_index_b: int = indices[index_offset + 1]
		var triangle_index_c: int = indices[index_offset + 2]
		if (
			triangle_index_a < 0 or triangle_index_a >= vertices.size()
			or triangle_index_b < 0 or triangle_index_b >= vertices.size()
			or triangle_index_c < 0 or triangle_index_c >= vertices.size()
		):
			continue
		_append_editable_mesh_triangle_to_canonical_geometry(
			canonical_geometry,
			vertices,
			normals,
			triangle_index_a,
			triangle_index_b,
			triangle_index_c
		)
	return canonical_geometry

func _append_editable_mesh_triangle_to_canonical_geometry(
	canonical_geometry,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	vertex_index_a: int,
	vertex_index_b: int,
	vertex_index_c: int
) -> void:
	if canonical_geometry == null:
		return
	var vertex_a: Vector3 = vertices[vertex_index_a]
	var vertex_b: Vector3 = vertices[vertex_index_b]
	var vertex_c: Vector3 = vertices[vertex_index_c]
	var resolved_normal: Vector3 = (vertex_b - vertex_a).cross(vertex_c - vertex_a).normalized()
	if resolved_normal == Vector3.ZERO:
		return
	var surface_triangle = CraftedItemCanonicalSurfaceTriangleScript.new()
	surface_triangle.vertex_a_local = vertex_a
	surface_triangle.vertex_b_local = vertex_b
	surface_triangle.vertex_c_local = vertex_c
	surface_triangle.normal = resolved_normal
	if normals.size() == vertices.size():
		surface_triangle.vertex_a_normal = normals[vertex_index_a]
		surface_triangle.vertex_b_normal = normals[vertex_index_b]
		surface_triangle.vertex_c_normal = normals[vertex_index_c]
	canonical_geometry.surface_triangles.append(surface_triangle)

func _build_current_canonical_geometry_with_unified_shell_overlay(
	source_solid = null,
	restricted_shell_quad_lookup: Dictionary = {},
	include_transition_walls: bool = true
):
	var canonical_geometry = current_shell_mesh_state.call("build_canonical_geometry", source_solid)
	if patch_states.is_empty():
		return canonical_geometry
	var overridden_shell_quad_lookup: Dictionary = _build_overridden_shell_quad_lookup()
	if overridden_shell_quad_lookup.is_empty():
		return canonical_geometry
	_ensure_shell_offset_storage_for_geometry_build()
	var merged_geometry = CraftedItemCanonicalGeometryScript.new()
	merged_geometry.source_solid = source_solid
	merged_geometry.local_aabb = canonical_geometry.local_aabb
	for shell_quad_state: Resource in current_shell_mesh_state.shell_quads:
		if shell_quad_state == null:
			continue
		var shell_quad_id: StringName = shell_quad_state.shell_quad_id
		if shell_quad_id == StringName() or not overridden_shell_quad_lookup.has(shell_quad_id):
			merged_geometry.surface_quads.append(shell_quad_state.build_canonical_surface_quad())
			continue
		if not restricted_shell_quad_lookup.is_empty() and not restricted_shell_quad_lookup.has(shell_quad_id):
			merged_geometry.surface_quads.append(shell_quad_state.build_canonical_surface_quad())
			continue
		_append_localized_shell_quad_geometry(
			merged_geometry,
			shell_quad_state,
			include_transition_walls
		)
	return merged_geometry

func _append_localized_shell_quad_geometry(
	merged_geometry,
	shell_quad_state: Resource,
	include_transition_walls: bool = true
) -> void:
	if merged_geometry == null or shell_quad_state == null:
		return
	var full_width_steps: int = maxi(shell_quad_state.width_voxels, 1)
	var full_height_steps: int = maxi(shell_quad_state.height_voxels, 1)
	var edge_u_step: Vector3 = shell_quad_state.edge_u_local / float(full_width_steps)
	var edge_v_step: Vector3 = shell_quad_state.edge_v_local / float(full_height_steps)
	var patch_offset_lookup: Dictionary = _build_shell_patch_offset_lookup(
		shell_quad_state
	)
	var changed_patch_coord_lookup: Dictionary = _build_changed_patch_coord_lookup(
		shell_quad_state
	)
	var localized_bounds: Dictionary = _resolve_shell_rebuild_bounds(
		changed_patch_coord_lookup,
		full_width_steps,
		full_height_steps
	)
	_append_shell_outer_strip_quads(
		merged_geometry,
		shell_quad_state,
		localized_bounds,
		full_width_steps,
		full_height_steps,
		edge_u_step,
		edge_v_step
	)
	var localized_shell_quad_state: Resource = _build_localized_shell_quad_state(
		shell_quad_state,
		localized_bounds,
		edge_u_step,
		edge_v_step
	)
	var localized_width_steps: int = int(localized_bounds.get("width", 0))
	var localized_height_steps: int = int(localized_bounds.get("height", 0))
	var vertex_grid: Array = _build_shell_vertex_grid(
		shell_quad_state,
		patch_offset_lookup,
		full_width_steps,
		full_height_steps,
		int(localized_bounds.get("start_u", 0)),
		int(localized_bounds.get("start_v", 0)),
		localized_width_steps,
		localized_height_steps,
		edge_u_step,
		edge_v_step
	)
	var vertex_normal_grid: Array = _build_shell_vertex_normal_grid(
		vertex_grid,
		localized_width_steps,
		localized_height_steps,
		localized_shell_quad_state.normal
	)
	_append_shell_surface_triangles(
		merged_geometry,
		localized_shell_quad_state,
		vertex_grid,
		vertex_normal_grid,
		localized_width_steps,
		localized_height_steps,
		patch_offset_lookup,
		full_width_steps,
		full_height_steps,
		int(localized_bounds.get("start_u", 0)),
		int(localized_bounds.get("start_v", 0)),
		edge_u_step,
		edge_v_step,
		localized_shell_quad_state.material_variant_id,
		localized_shell_quad_state.normal,
		true
	)
	if include_transition_walls:
		_append_shell_boundary_wall_triangles(
			merged_geometry,
			vertex_grid,
			localized_width_steps,
			localized_height_steps,
			localized_shell_quad_state,
			edge_u_step,
			edge_v_step
		)

func _resolve_shell_rebuild_bounds(
	changed_patch_coord_lookup: Dictionary,
	full_width_steps: int,
	full_height_steps: int
) -> Dictionary:
	if _should_rebuild_full_shell_quad_from_offsets(changed_patch_coord_lookup):
		return {
			"start_u": 0,
			"start_v": 0,
			"end_u": full_width_steps,
			"end_v": full_height_steps,
			"width": full_width_steps,
			"height": full_height_steps,
		}
	return _resolve_localized_shell_patch_bounds(
		changed_patch_coord_lookup,
		full_width_steps,
		full_height_steps
	)

func _should_rebuild_full_shell_quad_from_offsets(changed_patch_coord_lookup: Dictionary) -> bool:
	return not changed_patch_coord_lookup.is_empty()

func refresh_current_local_aabb_from_patches() -> void:
	if editable_mesh_visual_authority and has_current_editable_mesh():
		var editable_mesh_position: Variant = current_editable_mesh_state.get("local_aabb_position")
		var editable_mesh_size: Variant = current_editable_mesh_state.get("local_aabb_size")
		if editable_mesh_position is Vector3 and editable_mesh_size is Vector3:
			current_local_aabb_position = editable_mesh_position
			current_local_aabb_size = editable_mesh_size
			return
	var canonical_geometry = build_current_canonical_geometry()
	if canonical_geometry == null or canonical_geometry.is_empty():
		current_local_aabb_position = baseline_local_aabb_position
		current_local_aabb_size = baseline_local_aabb_size
		return
	var has_vertex: bool = false
	var min_vertex: Vector3 = Vector3.ZERO
	var max_vertex: Vector3 = Vector3.ZERO
	for surface_quad in canonical_geometry.surface_quads:
		if surface_quad == null:
			continue
		for vertex: Vector3 in surface_quad.get_vertices():
			if not has_vertex:
				min_vertex = vertex
				max_vertex = vertex
				has_vertex = true
				continue
			min_vertex = min_vertex.min(vertex)
			max_vertex = max_vertex.max(vertex)
	for surface_triangle in canonical_geometry.surface_triangles:
		if surface_triangle == null:
			continue
		for vertex: Vector3 in surface_triangle.get_vertices():
			if not has_vertex:
				min_vertex = vertex
				max_vertex = vertex
				has_vertex = true
				continue
			min_vertex = min_vertex.min(vertex)
			max_vertex = max_vertex.max(vertex)
	if not has_vertex:
		current_local_aabb_position = baseline_local_aabb_position
		current_local_aabb_size = baseline_local_aabb_size
		return
	current_local_aabb_position = min_vertex
	current_local_aabb_size = max_vertex - min_vertex

func _has_patch_override_geometry() -> bool:
	if patch_states.is_empty():
		return false
	for patch_state in patch_states:
		if not _is_patch_state_overridden(patch_state):
			continue
		return true
	return false

func _build_overridden_shell_quad_lookup() -> Dictionary:
	var shell_quad_lookup: Dictionary = {}
	if not has_unified_shell():
		return shell_quad_lookup
	var patch_states_by_shell_quad_id: Dictionary = _build_patch_states_by_shell_quad_id()
	for shell_quad_state in current_shell_mesh_state.shell_quads:
		if shell_quad_state == null or shell_quad_state.shell_quad_id == StringName():
			continue
		var shell_patch_states: Array = patch_states_by_shell_quad_id.get(shell_quad_state.shell_quad_id, [])
		if _shell_quad_has_deformation(shell_quad_state, shell_patch_states):
			shell_quad_lookup[shell_quad_state.shell_quad_id] = true
	return shell_quad_lookup

func _build_patch_states_by_shell_quad_id() -> Dictionary:
	var shell_quad_patch_lookup: Dictionary = {}
	for patch_state in patch_states:
		if patch_state == null or patch_state.shell_quad_id == StringName():
			continue
		var patch_state_group: Array = shell_quad_patch_lookup.get(patch_state.shell_quad_id, [])
		patch_state_group.append(patch_state)
		shell_quad_patch_lookup[patch_state.shell_quad_id] = patch_state_group
	return shell_quad_patch_lookup

func _parse_shell_edge_id(shell_edge_id: StringName) -> Dictionary:
	var shell_edge_text: String = String(shell_edge_id)
	if shell_edge_text.is_empty():
		return {}
	var separator_index: int = shell_edge_text.rfind("::")
	if separator_index == -1:
		return {}
	return {
		"shell_quad_id": StringName(shell_edge_text.substr(0, separator_index)),
		"boundary_edge_id": StringName(shell_edge_text.substr(separator_index + 2)),
	}

func _parse_shell_feature_edge_id(shell_feature_edge_id: StringName) -> Dictionary:
	var shell_feature_edge_parts: PackedStringArray = String(shell_feature_edge_id).split("::")
	if shell_feature_edge_parts.size() != 3:
		return {}
	var split_index: int = int(shell_feature_edge_parts[2])
	if split_index <= 0:
		return {}
	return {
		"shell_quad_id": StringName(shell_feature_edge_parts[0]),
		"orientation": StringName(shell_feature_edge_parts[1]),
		"split_index": split_index,
	}

func _parse_shell_feature_region_id(shell_feature_region_id: StringName) -> Dictionary:
	var shell_feature_region_parts: PackedStringArray = String(shell_feature_region_id).split("::")
	if shell_feature_region_parts.size() != 3:
		return {}
	if shell_feature_region_parts[1] != "region":
		return {}
	return {
		"shell_quad_id": StringName(shell_feature_region_parts[0]),
		"anchor_patch_id": StringName(shell_feature_region_parts[2]),
	}

func _parse_shell_feature_band_id(shell_feature_band_id: StringName) -> Dictionary:
	var shell_feature_band_parts: PackedStringArray = String(shell_feature_band_id).split("::")
	if shell_feature_band_parts.size() != 3:
		return {}
	if shell_feature_band_parts[1] != "band":
		return {}
	return {
		"shell_quad_id": StringName(shell_feature_band_parts[0]),
		"anchor_patch_id": StringName(shell_feature_band_parts[2]),
	}

func _parse_shell_feature_cluster_id(shell_feature_cluster_id: StringName) -> Dictionary:
	var shell_feature_cluster_parts: PackedStringArray = String(shell_feature_cluster_id).split("::")
	if shell_feature_cluster_parts.size() != 3:
		return {}
	if shell_feature_cluster_parts[1] != "cluster":
		return {}
	return {
		"shell_quad_id": StringName(shell_feature_cluster_parts[0]),
		"anchor_patch_id": StringName(shell_feature_cluster_parts[2]),
	}

func _parse_shell_feature_bridge_id(shell_feature_bridge_id: StringName) -> Dictionary:
	var shell_feature_bridge_parts: PackedStringArray = String(shell_feature_bridge_id).split("::")
	if shell_feature_bridge_parts.size() != 3:
		return {}
	if shell_feature_bridge_parts[1] != "bridge":
		return {}
	return {
		"shell_quad_id": StringName(shell_feature_bridge_parts[0]),
		"anchor_patch_id": StringName(shell_feature_bridge_parts[2]),
	}

func _parse_shell_feature_contour_id(shell_feature_contour_id: StringName) -> Dictionary:
	var shell_feature_contour_parts: PackedStringArray = String(shell_feature_contour_id).split("::")
	if shell_feature_contour_parts.size() != 3:
		return {}
	if shell_feature_contour_parts[1] != "contour":
		return {}
	return {
		"shell_quad_id": StringName(shell_feature_contour_parts[0]),
		"anchor_patch_id": StringName(shell_feature_contour_parts[2]),
	}

func _parse_shell_feature_loop_id(shell_feature_loop_id: StringName) -> Dictionary:
	var shell_feature_loop_parts: PackedStringArray = String(shell_feature_loop_id).split("::")
	if shell_feature_loop_parts.size() != 3:
		return {}
	if shell_feature_loop_parts[1] != "loop":
		return {}
	return {
		"shell_quad_id": StringName(shell_feature_loop_parts[0]),
		"anchor_patch_id": StringName(shell_feature_loop_parts[2]),
	}

func resolve_connected_offset_feature_region_patch_ids_from_patch_id(anchor_patch_id: StringName) -> PackedStringArray:
	var anchor_patch_state: Resource = _find_patch_state_by_id(anchor_patch_id)
	if anchor_patch_state == null:
		return PackedStringArray()
	return _resolve_connected_offset_feature_region_patch_ids_from_anchor(anchor_patch_state)

func resolve_feature_band_patch_ids_from_patch_id(anchor_patch_id: StringName) -> PackedStringArray:
	var anchor_patch_state: Resource = _find_patch_state_by_id(anchor_patch_id)
	if anchor_patch_state == null:
		return PackedStringArray()
	var region_patch_ids: PackedStringArray = _resolve_connected_offset_feature_region_patch_ids_from_anchor(anchor_patch_state)
	return _resolve_feature_band_patch_ids_for_region(region_patch_ids)

func resolve_feature_cluster_patch_ids_from_patch_id(anchor_patch_id: StringName) -> PackedStringArray:
	var anchor_patch_state: Resource = _find_patch_state_by_id(anchor_patch_id)
	if anchor_patch_state == null:
		return PackedStringArray()
	return _resolve_feature_cluster_patch_ids_from_anchor(anchor_patch_state)

func resolve_feature_bridge_patch_ids_from_patch_id(anchor_patch_id: StringName) -> PackedStringArray:
	var anchor_patch_state: Resource = _find_patch_state_by_id(anchor_patch_id)
	if anchor_patch_state == null:
		return PackedStringArray()
	return _resolve_feature_bridge_patch_ids_from_anchor(anchor_patch_state)

func resolve_feature_contour_patch_ids_from_patch_id(anchor_patch_id: StringName) -> PackedStringArray:
	var anchor_patch_state: Resource = _find_patch_state_by_id(anchor_patch_id)
	if anchor_patch_state == null:
		return PackedStringArray()
	var bridge_patch_ids: PackedStringArray = _resolve_feature_bridge_patch_ids_from_anchor(anchor_patch_state)
	return _resolve_feature_contour_patch_ids_for_bridge(bridge_patch_ids)

func resolve_feature_loop_patch_ids_from_patch_id(anchor_patch_id: StringName) -> PackedStringArray:
	var anchor_patch_state: Resource = _find_patch_state_by_id(anchor_patch_id)
	if anchor_patch_state == null:
		return PackedStringArray()
	var region_patch_ids: PackedStringArray = _resolve_connected_offset_feature_region_patch_ids_from_anchor(anchor_patch_state)
	return _resolve_feature_loop_patch_ids_for_region(region_patch_ids)

func resolve_hover_selection_data(hit_data: Dictionary, tool_id: StringName) -> Dictionary:
	var hovered_face_id: StringName = _resolve_hover_face_id_from_selection_hit(hit_data)
	var hovered_patch_id: StringName = _resolve_hover_patch_id_from_selection_hit(hit_data)
	if hovered_patch_id == StringName() and hovered_face_id == StringName():
		return {}
	if _is_surface_face_selection_tool(tool_id):
		if hovered_face_id == StringName():
			var face_patch_state: Resource = _find_patch_state_by_id(hovered_patch_id)
			if face_patch_state == null or face_patch_state.current_quad == null:
				return {}
			hovered_face_id = face_patch_state.shell_quad_id
		if hovered_face_id == StringName():
			return {}
		var face_ids: PackedStringArray = PackedStringArray([String(hovered_face_id)])
		var face_patch_ids: PackedStringArray = resolve_patch_ids_for_face_ids(face_ids)
		if face_patch_ids.is_empty():
			return {}
		return {
			"face_ids": face_ids,
			"patch_ids": face_patch_ids,
			"primary_patch_id": hovered_patch_id,
			"primary_face_id": hovered_face_id,
			"target_kind": &"surface_face",
		}
	if _is_surface_edge_selection_tool(tool_id):
		if hovered_face_id != StringName():
			var face_edge_id: StringName = _resolve_nearest_shell_boundary_edge_id(
				hovered_face_id,
				hit_data.get("hit_point_canonical_local", null)
			)
			if face_edge_id != StringName():
				var face_edge_ids: PackedStringArray = PackedStringArray([String(face_edge_id)])
				var face_edge_patch_ids: PackedStringArray = resolve_patch_ids_for_shell_edge_ids(face_edge_ids)
				if not face_edge_patch_ids.is_empty():
					return {
						"edge_ids": face_edge_ids,
						"patch_ids": face_edge_patch_ids,
						"primary_patch_id": hovered_patch_id,
						"primary_face_id": hovered_face_id,
						"primary_edge_id": face_edge_id,
						"target_kind": &"surface_edge",
					}
		if hovered_patch_id == StringName():
			return {}
		var edge_patch_state: Resource = _find_patch_state_by_id(hovered_patch_id)
		if edge_patch_state == null or edge_patch_state.current_quad == null:
			return {}
		var edge_hit_point_local: Variant = hit_data.get("hit_point_canonical_local", null)
		if edge_hit_point_local is not Vector3:
			return {}
		var edge_id: StringName = resolve_nearest_boundary_edge_id_for_patch_id(edge_patch_state.patch_id, edge_hit_point_local)
		if edge_id == StringName():
			return {}
		var edge_patch_ids: PackedStringArray = resolve_boundary_edge_run_patch_ids_from_patch_id(edge_patch_state.patch_id, edge_id)
		if edge_patch_ids.is_empty():
			return {}
		return {
			"patch_ids": edge_patch_ids,
			"primary_patch_id": hovered_patch_id,
			"target_kind": &"surface_edge",
			"edge_id": edge_id,
		}
	if _is_surface_feature_edge_selection_tool(tool_id):
		if hovered_face_id != StringName():
			var feature_edge_id: StringName = _resolve_nearest_shell_feature_edge_id(
				hovered_face_id,
				hit_data.get("hit_point_canonical_local", null)
			)
			if feature_edge_id != StringName():
				var feature_edge_ids: PackedStringArray = PackedStringArray([String(feature_edge_id)])
				var feature_edge_patch_ids: PackedStringArray = resolve_patch_ids_for_shell_feature_edge_ids(feature_edge_ids)
				if not feature_edge_patch_ids.is_empty():
					return {
						"edge_ids": feature_edge_ids,
						"patch_ids": feature_edge_patch_ids,
						"primary_patch_id": hovered_patch_id,
						"primary_face_id": hovered_face_id,
						"primary_edge_id": feature_edge_id,
						"target_kind": &"surface_feature_edge",
					}
		if hovered_patch_id == StringName():
			return {}
		var feature_edge_patch_state: Resource = _find_patch_state_by_id(hovered_patch_id)
		if feature_edge_patch_state == null or feature_edge_patch_state.current_quad == null:
			return {}
		var feature_edge_hit_point_local: Variant = hit_data.get("hit_point_canonical_local", null)
		if feature_edge_hit_point_local is not Vector3:
			return {}
		var internal_edge_id: StringName = resolve_nearest_internal_feature_edge_id_for_patch_id(
			feature_edge_patch_state.patch_id,
			feature_edge_hit_point_local
		)
		if internal_edge_id == StringName():
			return {}
		var internal_edge_patch_ids: PackedStringArray = resolve_internal_feature_edge_run_patch_ids_from_patch_id(
			feature_edge_patch_state.patch_id,
			internal_edge_id
		)
		if internal_edge_patch_ids.is_empty():
			return {}
		return {
			"patch_ids": internal_edge_patch_ids,
			"primary_patch_id": hovered_patch_id,
			"target_kind": &"surface_feature_edge",
			"edge_id": internal_edge_id,
		}
	if _is_surface_feature_region_selection_tool(tool_id):
		var region_patch_state: Resource = _find_patch_state_by_id(hovered_patch_id)
		if region_patch_state == null or region_patch_state.current_quad == null:
			return {}
		var region_patch_ids: PackedStringArray = resolve_connected_offset_feature_region_patch_ids_from_patch_id(region_patch_state.patch_id)
		if region_patch_ids.is_empty():
			return {}
		var region_id: StringName = _build_shell_feature_region_identifier(region_patch_state.shell_quad_id, region_patch_ids)
		return {
			"region_ids": PackedStringArray([String(region_id)]),
			"patch_ids": region_patch_ids,
			"primary_patch_id": hovered_patch_id,
			"primary_face_id": hovered_face_id,
			"primary_region_id": region_id,
			"target_kind": &"surface_feature_region",
		}
	if _is_surface_feature_band_selection_tool(tool_id):
		var band_patch_state: Resource = _find_patch_state_by_id(hovered_patch_id)
		if band_patch_state == null or band_patch_state.current_quad == null:
			return {}
		var band_region_patch_ids: PackedStringArray = resolve_connected_offset_feature_region_patch_ids_from_patch_id(band_patch_state.patch_id)
		if band_region_patch_ids.is_empty():
			return {}
		var band_patch_ids: PackedStringArray = resolve_feature_band_patch_ids_from_patch_id(band_patch_state.patch_id)
		if band_patch_ids.is_empty():
			return {}
		var band_id: StringName = _build_shell_feature_band_identifier(band_patch_state.shell_quad_id, band_region_patch_ids)
		return {
			"band_ids": PackedStringArray([String(band_id)]),
			"patch_ids": band_patch_ids,
			"primary_patch_id": hovered_patch_id,
			"primary_face_id": hovered_face_id,
			"primary_band_id": band_id,
			"target_kind": &"surface_feature_band",
		}
	if _is_surface_feature_cluster_selection_tool(tool_id):
		var cluster_patch_state: Resource = _find_patch_state_by_id(hovered_patch_id)
		if cluster_patch_state == null or cluster_patch_state.current_quad == null:
			return {}
		var cluster_patch_ids: PackedStringArray = resolve_feature_cluster_patch_ids_from_patch_id(cluster_patch_state.patch_id)
		if cluster_patch_ids.is_empty():
			return {}
		var cluster_id: StringName = _build_shell_feature_cluster_identifier(cluster_patch_state.shell_quad_id, cluster_patch_ids)
		return {
			"cluster_ids": PackedStringArray([String(cluster_id)]),
			"patch_ids": cluster_patch_ids,
			"primary_patch_id": hovered_patch_id,
			"primary_face_id": hovered_face_id,
			"primary_cluster_id": cluster_id,
			"target_kind": &"surface_feature_cluster",
		}
	if _is_surface_feature_bridge_selection_tool(tool_id):
		var bridge_patch_state: Resource = _find_patch_state_by_id(hovered_patch_id)
		if bridge_patch_state == null or bridge_patch_state.current_quad == null:
			return {}
		var bridge_patch_ids: PackedStringArray = resolve_feature_bridge_patch_ids_from_patch_id(bridge_patch_state.patch_id)
		if bridge_patch_ids.is_empty():
			return {}
		var bridge_id: StringName = _build_shell_feature_bridge_identifier(bridge_patch_state.shell_quad_id, bridge_patch_ids)
		return {
			"bridge_ids": PackedStringArray([String(bridge_id)]),
			"patch_ids": bridge_patch_ids,
			"primary_patch_id": hovered_patch_id,
			"primary_face_id": hovered_face_id,
			"primary_bridge_id": bridge_id,
			"target_kind": &"surface_feature_bridge",
		}
	if _is_surface_feature_contour_selection_tool(tool_id):
		var contour_patch_state: Resource = _find_patch_state_by_id(hovered_patch_id)
		if contour_patch_state == null or contour_patch_state.current_quad == null:
			return {}
		var contour_patch_ids: PackedStringArray = resolve_feature_contour_patch_ids_from_patch_id(contour_patch_state.patch_id)
		if contour_patch_ids.is_empty():
			return {}
		var contour_id: StringName = _build_shell_feature_contour_identifier(contour_patch_state.shell_quad_id, contour_patch_ids)
		return {
			"contour_ids": PackedStringArray([String(contour_id)]),
			"patch_ids": contour_patch_ids,
			"primary_patch_id": hovered_patch_id,
			"primary_face_id": hovered_face_id,
			"primary_contour_id": contour_id,
			"target_kind": &"surface_feature_contour",
		}
	if _is_surface_feature_loop_selection_tool(tool_id):
		var loop_patch_state: Resource = _find_patch_state_by_id(hovered_patch_id)
		if loop_patch_state == null or loop_patch_state.current_quad == null:
			return {}
		var loop_region_patch_ids: PackedStringArray = resolve_connected_offset_feature_region_patch_ids_from_patch_id(loop_patch_state.patch_id)
		if loop_region_patch_ids.is_empty():
			return {}
		var loop_patch_ids: PackedStringArray = resolve_feature_loop_patch_ids_from_patch_id(loop_patch_state.patch_id)
		if loop_patch_ids.is_empty():
			return {}
		var loop_id: StringName = _build_shell_feature_loop_identifier(loop_patch_state.shell_quad_id, loop_patch_ids)
		return {
			"loop_ids": PackedStringArray([String(loop_id)]),
			"patch_ids": loop_patch_ids,
			"primary_patch_id": hovered_patch_id,
			"primary_face_id": hovered_face_id,
			"primary_loop_id": loop_id,
			"target_kind": &"surface_feature_loop",
		}
	return {}

func resolve_patch_ids_for_selection_identifiers(
	tool_id: StringName,
	face_ids: PackedStringArray = PackedStringArray(),
	edge_ids: PackedStringArray = PackedStringArray(),
	region_ids: PackedStringArray = PackedStringArray(),
	band_ids: PackedStringArray = PackedStringArray(),
	cluster_ids: PackedStringArray = PackedStringArray(),
	bridge_ids: PackedStringArray = PackedStringArray(),
	contour_ids: PackedStringArray = PackedStringArray(),
	loop_ids: PackedStringArray = PackedStringArray()
) -> PackedStringArray:
	if _is_surface_face_selection_tool(tool_id):
		return resolve_patch_ids_for_face_ids(face_ids)
	if _is_surface_edge_selection_tool(tool_id):
		return resolve_patch_ids_for_shell_edge_ids(edge_ids)
	if _is_surface_feature_edge_selection_tool(tool_id):
		return resolve_patch_ids_for_shell_feature_edge_ids(edge_ids)
	if _is_surface_feature_region_selection_tool(tool_id):
		return resolve_patch_ids_for_shell_feature_region_ids(region_ids)
	if _is_surface_feature_band_selection_tool(tool_id):
		return resolve_patch_ids_for_shell_feature_band_ids(band_ids)
	if _is_surface_feature_cluster_selection_tool(tool_id):
		return resolve_patch_ids_for_shell_feature_cluster_ids(cluster_ids)
	if _is_surface_feature_bridge_selection_tool(tool_id):
		return resolve_patch_ids_for_shell_feature_bridge_ids(bridge_ids)
	if _is_surface_feature_contour_selection_tool(tool_id):
		return resolve_patch_ids_for_shell_feature_contour_ids(contour_ids)
	if _is_surface_feature_loop_selection_tool(tool_id):
		return resolve_patch_ids_for_shell_feature_loop_ids(loop_ids)
	return PackedStringArray()

func resolve_selection_apply_patch_ids(selected_patch_ids: PackedStringArray, tool_id: StringName) -> PackedStringArray:
	if selected_patch_ids.is_empty():
		return PackedStringArray()
	if _is_surface_face_selection_tool(tool_id):
		return resolve_boundary_loop_patch_ids_for_selection(selected_patch_ids)
	if (
		_is_surface_edge_selection_tool(tool_id)
		or _is_surface_feature_edge_selection_tool(tool_id)
		or _is_surface_feature_region_selection_tool(tool_id)
		or _is_surface_feature_band_selection_tool(tool_id)
		or _is_surface_feature_cluster_selection_tool(tool_id)
		or _is_surface_feature_bridge_selection_tool(tool_id)
		or _is_surface_feature_contour_selection_tool(tool_id)
		or _is_surface_feature_loop_selection_tool(tool_id)
	):
		return PackedStringArray(selected_patch_ids)
	return PackedStringArray()

func resolve_selection_apply_state(
	tool_id: StringName,
	face_ids: PackedStringArray = PackedStringArray(),
	edge_ids: PackedStringArray = PackedStringArray(),
	region_ids: PackedStringArray = PackedStringArray(),
	band_ids: PackedStringArray = PackedStringArray(),
	cluster_ids: PackedStringArray = PackedStringArray(),
	bridge_ids: PackedStringArray = PackedStringArray(),
	contour_ids: PackedStringArray = PackedStringArray(),
	loop_ids: PackedStringArray = PackedStringArray()
) -> Dictionary:
	var selected_patch_ids: PackedStringArray = resolve_patch_ids_for_selection_identifiers(
		tool_id,
		face_ids,
		edge_ids,
		region_ids,
		band_ids,
		cluster_ids,
		bridge_ids,
		contour_ids,
		loop_ids
	)
	if selected_patch_ids.is_empty():
		return {
			"selected_patch_ids": PackedStringArray(),
			"apply_patch_ids": PackedStringArray(),
			"editable_mesh_vertex_indices": PackedInt32Array(),
		}
	var apply_patch_ids: PackedStringArray = resolve_selection_apply_patch_ids(selected_patch_ids, tool_id)
	var target_patch_ids: PackedStringArray = (
		apply_patch_ids if not apply_patch_ids.is_empty() else selected_patch_ids
	)
	var editable_mesh_vertex_indices: PackedInt32Array = PackedInt32Array()
	if not target_patch_ids.is_empty():
		editable_mesh_vertex_indices = resolve_editable_mesh_vertex_indices_for_patch_ids(target_patch_ids)
	return {
		"selected_patch_ids": selected_patch_ids,
		"apply_patch_ids": apply_patch_ids,
		"editable_mesh_vertex_indices": editable_mesh_vertex_indices,
	}

func get_patch_state_by_id(patch_id: StringName) -> Resource:
	return _find_patch_state_by_id(patch_id)

func resolve_boundary_loop_patch_ids_for_selection(selected_patch_ids: PackedStringArray) -> PackedStringArray:
	if selected_patch_ids.is_empty():
		return PackedStringArray()
	var patch_lookup: Dictionary = _build_patch_lookup()
	var selected_lookup: Dictionary = {}
	for patch_id: String in selected_patch_ids:
		selected_lookup[StringName(patch_id)] = true
	var boundary_patch_ids: PackedStringArray = PackedStringArray()
	for patch_id: String in selected_patch_ids:
		var patch_state: Resource = patch_lookup.get(StringName(patch_id), null)
		if patch_state == null or patch_state.current_quad == null:
			continue
		if _patch_has_selection_boundary_edge(patch_lookup, patch_state, selected_lookup):
			boundary_patch_ids.append(patch_id)
	if boundary_patch_ids.is_empty():
		return PackedStringArray(selected_patch_ids)
	return boundary_patch_ids

func resolve_nearest_boundary_edge_id_for_patch_id(anchor_patch_id: StringName, hit_point_local: Vector3) -> StringName:
	var patch_state: Resource = _find_patch_state_by_id(anchor_patch_id)
	if patch_state == null or patch_state.current_quad == null:
		return StringName()
	return _resolve_nearest_boundary_edge_id_for_patch(patch_state, hit_point_local)

func resolve_boundary_edge_run_patch_ids_from_patch_id(anchor_patch_id: StringName, edge_id: StringName) -> PackedStringArray:
	var patch_state: Resource = _find_patch_state_by_id(anchor_patch_id)
	if patch_state == null or patch_state.current_quad == null:
		return PackedStringArray()
	return _resolve_boundary_edge_run_patch_ids_for_patch(patch_state, edge_id)

func resolve_nearest_internal_feature_edge_id_for_patch_id(anchor_patch_id: StringName, hit_point_local: Vector3) -> StringName:
	var patch_state: Resource = _find_patch_state_by_id(anchor_patch_id)
	if patch_state == null or patch_state.current_quad == null:
		return StringName()
	return _resolve_nearest_internal_feature_edge_id_for_patch(patch_state, hit_point_local)

func resolve_internal_feature_edge_run_patch_ids_from_patch_id(anchor_patch_id: StringName, edge_id: StringName) -> PackedStringArray:
	var patch_state: Resource = _find_patch_state_by_id(anchor_patch_id)
	if patch_state == null or patch_state.current_quad == null:
		return PackedStringArray()
	return _resolve_internal_feature_edge_run_patch_ids_for_patch(patch_state, edge_id)

func _resolve_connected_offset_feature_region_patch_ids_from_anchor(anchor_patch_state: Resource) -> PackedStringArray:
	if anchor_patch_state == null or anchor_patch_state.current_quad == null:
		return PackedStringArray()
	var patch_lookup: Dictionary = {}
	for patch_state in patch_states:
		if patch_state == null:
			continue
		patch_lookup[patch_state.patch_id] = patch_state
	var anchor_offset_cells: float = resolve_current_offset_cells(anchor_patch_state)
	var visited_lookup: Dictionary = {}
	var pending_patch_ids: Array[StringName] = [anchor_patch_state.patch_id]
	var patch_ids: PackedStringArray = PackedStringArray()
	while not pending_patch_ids.is_empty():
		var patch_id: StringName = pending_patch_ids.pop_back()
		if patch_id == StringName() or visited_lookup.has(patch_id):
			continue
		visited_lookup[patch_id] = true
		var patch_state: Resource = patch_lookup.get(patch_id, null)
		if patch_state == null or patch_state.current_quad == null:
			continue
		if patch_state.zone_mask_id != anchor_patch_state.zone_mask_id:
			continue
		if patch_state.shell_quad_id != anchor_patch_state.shell_quad_id:
			continue
		if not _shares_plane_and_normal(anchor_patch_state.current_quad, patch_state.current_quad):
			continue
		if not is_equal_approx(resolve_current_offset_cells(patch_state), anchor_offset_cells):
			continue
		patch_ids.append(String(patch_id))
		for neighbor_patch_id_string: String in patch_state.neighbor_patch_ids:
			var neighbor_patch_id: StringName = StringName(neighbor_patch_id_string)
			if visited_lookup.has(neighbor_patch_id):
				continue
			pending_patch_ids.append(neighbor_patch_id)
	return patch_ids

func resolve_current_offset_cells(patch_state: Resource) -> float:
	if patch_state == null:
		return 0.0
	if (
		editable_mesh_visual_authority
		and has_current_editable_mesh()
		and current_editable_mesh_state != null
		and bool(current_editable_mesh_state.get("dirty"))
	):
		var editable_mesh_offset_cells: float = float(patch_state.get("current_offset_cells"))
		if patch_state.baseline_quad != null and patch_state.current_quad != null:
			var current_geometry_offset_cells: float = _resolve_geometry_offset_cells(patch_state)
			if not is_equal_approx(editable_mesh_offset_cells, current_geometry_offset_cells):
				_sync_patch_current_quad_from_offset_cells(patch_state, editable_mesh_offset_cells)
		return editable_mesh_offset_cells
	var shell_offset_data: Dictionary = _resolve_shell_patch_offset_data_for_patch(patch_state)
	if not shell_offset_data.is_empty():
		var shell_offset_cells: float = float(shell_offset_data.get("value", 0.0))
		patch_state.current_offset_cells = shell_offset_cells
		if patch_state.baseline_quad != null and patch_state.current_quad != null:
			var current_geometry_offset_cells: float = _resolve_geometry_offset_cells(patch_state)
			if not is_equal_approx(shell_offset_cells, current_geometry_offset_cells):
				_sync_patch_current_quad_from_offset_cells(patch_state, shell_offset_cells)
		return shell_offset_cells
	var stored_offset_cells: float = float(patch_state.get("current_offset_cells"))
	if patch_state.baseline_quad == null or patch_state.current_quad == null:
		return stored_offset_cells
	var geometry_offset_cells: float = _resolve_geometry_offset_cells(patch_state)
	if is_zero_approx(stored_offset_cells) and not is_zero_approx(geometry_offset_cells):
		patch_state.current_offset_cells = geometry_offset_cells
		set_shell_patch_offset_cells_for_patch(patch_state, geometry_offset_cells)
		return geometry_offset_cells
	if not is_equal_approx(stored_offset_cells, geometry_offset_cells):
		_sync_patch_current_quad_from_offset_cells(patch_state, stored_offset_cells)
	return stored_offset_cells

func _find_patch_state_by_id(patch_id: StringName) -> Resource:
	if patch_id == StringName():
		return null
	for patch_state in patch_states:
		if patch_state == null or patch_state.patch_id != patch_id:
			continue
		return patch_state
	return null

func _build_patch_lookup() -> Dictionary:
	var patch_lookup: Dictionary = {}
	for patch_state in patch_states:
		if patch_state == null:
			continue
		patch_lookup[patch_state.patch_id] = patch_state
	return patch_lookup

func _append_unique_patch_id(target_patch_ids: PackedStringArray, patch_id: String) -> void:
	if patch_id.is_empty() or target_patch_ids.find(patch_id) != -1:
		return
	target_patch_ids.append(patch_id)

func _resolve_nearest_boundary_edge_id_for_patch(patch_state: Resource, hit_point_local: Vector3) -> StringName:
	if patch_state == null or patch_state.current_quad == null:
		return StringName()
	var candidate_edges: Array[Dictionary] = []
	for edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
		if not _is_boundary_edge(patch_state, edge_id):
			continue
		var edge_segment: Dictionary = _build_edge_segment(patch_state.current_quad, edge_id)
		var distance_to_edge: float = _distance_point_to_segment(
			hit_point_local,
			edge_segment.get("start", Vector3.ZERO),
			edge_segment.get("end", Vector3.ZERO)
		)
		candidate_edges.append({
			"edge_id": edge_id,
			"distance": distance_to_edge,
		})
	if candidate_edges.is_empty():
		return StringName()
	candidate_edges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", INF)) < float(b.get("distance", INF))
	)
	return StringName(candidate_edges[0].get("edge_id", StringName()))

func _resolve_nearest_internal_feature_edge_id_for_patch(patch_state: Resource, hit_point_local: Vector3) -> StringName:
	if patch_state == null or patch_state.current_quad == null:
		return StringName()
	var candidate_edges: Array[Dictionary] = []
	for edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
		if not _is_internal_feature_edge(patch_state, edge_id):
			continue
		var edge_segment: Dictionary = _build_edge_segment(patch_state.current_quad, edge_id)
		var distance_to_edge: float = _distance_point_to_segment(
			hit_point_local,
			edge_segment.get("start", Vector3.ZERO),
			edge_segment.get("end", Vector3.ZERO)
		)
		candidate_edges.append({
			"edge_id": edge_id,
			"distance": distance_to_edge,
		})
	if candidate_edges.is_empty():
		return StringName()
	candidate_edges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", INF)) < float(b.get("distance", INF))
	)
	return StringName(candidate_edges[0].get("edge_id", StringName()))

func _resolve_boundary_edge_run_patch_ids_for_patch(patch_state: Resource, edge_id: StringName) -> PackedStringArray:
	if patch_state == null or patch_state.current_quad == null or edge_id == StringName():
		return PackedStringArray()
	var base_edge_segment: Dictionary = _build_edge_segment(patch_state.current_quad, edge_id)
	var direction: Vector3 = base_edge_segment.get("direction", Vector3.ZERO)
	if direction == Vector3.ZERO:
		return PackedStringArray([String(patch_state.patch_id)])
	var run_intervals: Array[Dictionary] = []
	for candidate_patch_state in patch_states:
		if candidate_patch_state == null or candidate_patch_state.current_quad == null:
			continue
		if not _shares_plane_and_normal(patch_state.current_quad, candidate_patch_state.current_quad):
			continue
		for candidate_edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
			if not _is_boundary_edge(candidate_patch_state, candidate_edge_id):
				continue
			var candidate_edge_segment: Dictionary = _build_edge_segment(candidate_patch_state.current_quad, candidate_edge_id)
			if not _edges_share_same_line(base_edge_segment, candidate_edge_segment):
				continue
			run_intervals.append({
				"patch_id": String(candidate_patch_state.patch_id),
				"interval": _resolve_edge_interval(candidate_edge_segment, base_edge_segment),
			})
			break
	if run_intervals.is_empty():
		return PackedStringArray()
	run_intervals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Vector2(a.get("interval", Vector2.ZERO)).x < Vector2(b.get("interval", Vector2.ZERO)).x
	)
	var selected_patch_key: String = String(patch_state.patch_id)
	var anchor_index: int = -1
	for interval_index: int in range(run_intervals.size()):
		if String(run_intervals[interval_index].get("patch_id", "")) == selected_patch_key:
			anchor_index = interval_index
			break
	if anchor_index == -1:
		return PackedStringArray()
	var selected_indices: Array[int] = [anchor_index]
	var current_min: float = Vector2(run_intervals[anchor_index].get("interval", Vector2.ZERO)).x
	var current_max: float = Vector2(run_intervals[anchor_index].get("interval", Vector2.ZERO)).y
	var scan_index: int = anchor_index - 1
	while scan_index >= 0:
		var scan_interval: Vector2 = run_intervals[scan_index].get("interval", Vector2.ZERO)
		if not _intervals_touch_or_overlap(scan_interval, Vector2(current_min, current_max)):
			break
		selected_indices.push_front(scan_index)
		current_min = minf(current_min, scan_interval.x)
		current_max = maxf(current_max, scan_interval.y)
		scan_index -= 1
	scan_index = anchor_index + 1
	while scan_index < run_intervals.size():
		var scan_interval: Vector2 = run_intervals[scan_index].get("interval", Vector2.ZERO)
		if not _intervals_touch_or_overlap(Vector2(current_min, current_max), scan_interval):
			break
		selected_indices.append(scan_index)
		current_min = minf(current_min, scan_interval.x)
		current_max = maxf(current_max, scan_interval.y)
		scan_index += 1
	var patch_ids: PackedStringArray = PackedStringArray()
	for selected_index: int in selected_indices:
		patch_ids.append(String(run_intervals[selected_index].get("patch_id", "")))
	return patch_ids

func _resolve_internal_feature_edge_run_patch_ids_for_patch(patch_state: Resource, edge_id: StringName) -> PackedStringArray:
	if patch_state == null or patch_state.current_quad == null or edge_id == StringName():
		return PackedStringArray()
	var base_edge_segment: Dictionary = _build_edge_segment(patch_state.current_quad, edge_id)
	var direction: Vector3 = base_edge_segment.get("direction", Vector3.ZERO)
	if direction == Vector3.ZERO:
		return PackedStringArray([String(patch_state.patch_id)])
	var interval_records_by_key: Dictionary = {}
	for candidate_patch_state in patch_states:
		if candidate_patch_state == null or candidate_patch_state.current_quad == null:
			continue
		if not _shares_plane_and_normal(patch_state.current_quad, candidate_patch_state.current_quad):
			continue
		for candidate_edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
			var adjacent_patch_ids: PackedStringArray = _resolve_internal_edge_adjacent_patch_ids(candidate_patch_state, candidate_edge_id)
			if adjacent_patch_ids.is_empty():
				continue
			var candidate_edge_segment: Dictionary = _build_edge_segment(candidate_patch_state.current_quad, candidate_edge_id)
			if not _edges_share_same_line(base_edge_segment, candidate_edge_segment):
				continue
			var segment_key: String = _build_edge_segment_key(candidate_edge_segment)
			var record: Dictionary = interval_records_by_key.get(segment_key, {
				"interval": _resolve_edge_interval(candidate_edge_segment, base_edge_segment),
				"patch_ids": PackedStringArray(),
				"segment_key": segment_key,
			})
			var record_patch_ids: PackedStringArray = PackedStringArray(record.get("patch_ids", PackedStringArray()))
			_append_unique_patch_id(record_patch_ids, String(candidate_patch_state.patch_id))
			for adjacent_patch_id_string: String in adjacent_patch_ids:
				_append_unique_patch_id(record_patch_ids, adjacent_patch_id_string)
			record["patch_ids"] = record_patch_ids
			interval_records_by_key[segment_key] = record
			break
	if interval_records_by_key.is_empty():
		return PackedStringArray()
	var run_intervals: Array[Dictionary] = []
	for record_key in interval_records_by_key.keys():
		run_intervals.append(interval_records_by_key[record_key])
	run_intervals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Vector2(a.get("interval", Vector2.ZERO)).x < Vector2(b.get("interval", Vector2.ZERO)).x
	)
	var anchor_key: String = _build_edge_segment_key(base_edge_segment)
	var anchor_index: int = -1
	for interval_index: int in range(run_intervals.size()):
		if String(run_intervals[interval_index].get("segment_key", "")) == anchor_key:
			anchor_index = interval_index
			break
	if anchor_index == -1:
		return PackedStringArray()
	var selected_indices: Array[int] = [anchor_index]
	var current_min: float = Vector2(run_intervals[anchor_index].get("interval", Vector2.ZERO)).x
	var current_max: float = Vector2(run_intervals[anchor_index].get("interval", Vector2.ZERO)).y
	var scan_index: int = anchor_index - 1
	while scan_index >= 0:
		var scan_interval: Vector2 = run_intervals[scan_index].get("interval", Vector2.ZERO)
		if not _intervals_touch_or_overlap(scan_interval, Vector2(current_min, current_max)):
			break
		selected_indices.push_front(scan_index)
		current_min = minf(current_min, scan_interval.x)
		current_max = maxf(current_max, scan_interval.y)
		scan_index -= 1
	scan_index = anchor_index + 1
	while scan_index < run_intervals.size():
		var scan_interval: Vector2 = run_intervals[scan_index].get("interval", Vector2.ZERO)
		if not _intervals_touch_or_overlap(Vector2(current_min, current_max), scan_interval):
			break
		selected_indices.append(scan_index)
		current_min = minf(current_min, scan_interval.x)
		current_max = maxf(current_max, scan_interval.y)
		scan_index += 1
	var patch_ids: PackedStringArray = PackedStringArray()
	for selected_index: int in selected_indices:
		var record_patch_ids: PackedStringArray = PackedStringArray(run_intervals[selected_index].get("patch_ids", PackedStringArray()))
		for patch_id: String in record_patch_ids:
			_append_unique_patch_id(patch_ids, patch_id)
	return patch_ids

func _is_boundary_edge(patch_state: Resource, edge_id: StringName) -> bool:
	if patch_state == null or patch_state.current_quad == null:
		return false
	var edge_segment: Dictionary = _build_edge_segment(patch_state.current_quad, edge_id)
	for candidate_patch_state in patch_states:
		if candidate_patch_state == null or candidate_patch_state == patch_state or candidate_patch_state.current_quad == null:
			continue
		if not _shares_plane_and_normal(patch_state.current_quad, candidate_patch_state.current_quad):
			continue
		for candidate_edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
			var candidate_segment: Dictionary = _build_edge_segment(candidate_patch_state.current_quad, candidate_edge_id)
			if _segments_match(edge_segment, candidate_segment):
				return false
	return true

func _is_internal_feature_edge(patch_state: Resource, edge_id: StringName) -> bool:
	return not _resolve_internal_edge_adjacent_patch_ids(patch_state, edge_id).is_empty()

func _patch_has_selection_boundary_edge(
	patch_lookup: Dictionary,
	patch_state: Resource,
	selected_lookup: Dictionary
) -> bool:
	if patch_state == null or patch_state.current_quad == null:
		return false
	for edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
		if _is_selection_boundary_edge(patch_lookup, patch_state, edge_id, selected_lookup):
			return true
	return false

func _is_selection_boundary_edge(
	patch_lookup: Dictionary,
	patch_state: Resource,
	edge_id: StringName,
	selected_lookup: Dictionary
) -> bool:
	var edge_segment: Dictionary = _build_edge_segment(patch_state.current_quad, edge_id)
	for neighbor_patch_id_string: String in patch_state.neighbor_patch_ids:
		var neighbor_patch_id: StringName = StringName(neighbor_patch_id_string)
		if not selected_lookup.has(neighbor_patch_id):
			continue
		var neighbor_patch_state: Resource = patch_lookup.get(neighbor_patch_id, null)
		if neighbor_patch_state == null or neighbor_patch_state.current_quad == null:
			continue
		for candidate_edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
			var candidate_segment: Dictionary = _build_edge_segment(neighbor_patch_state.current_quad, candidate_edge_id)
			if _segments_match(edge_segment, candidate_segment):
				return false
	return true

func _resolve_internal_edge_adjacent_patch_ids(patch_state: Resource, edge_id: StringName) -> PackedStringArray:
	if patch_state == null or patch_state.current_quad == null:
		return PackedStringArray()
	var edge_segment: Dictionary = _build_edge_segment(patch_state.current_quad, edge_id)
	var patch_lookup: Dictionary = _build_patch_lookup()
	var adjacent_patch_ids: PackedStringArray = PackedStringArray()
	if not patch_state.neighbor_patch_ids.is_empty():
		for neighbor_patch_id_string: String in patch_state.neighbor_patch_ids:
			var neighbor_patch_id: StringName = StringName(neighbor_patch_id_string)
			var neighbor_patch_state: Resource = patch_lookup.get(neighbor_patch_id, null)
			if neighbor_patch_state == null or neighbor_patch_state.current_quad == null:
				continue
			if not _shares_plane_and_normal(patch_state.current_quad, neighbor_patch_state.current_quad):
				continue
			for candidate_edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
				var candidate_segment: Dictionary = _build_edge_segment(neighbor_patch_state.current_quad, candidate_edge_id)
				if _segments_match(edge_segment, candidate_segment):
					_append_unique_patch_id(adjacent_patch_ids, String(neighbor_patch_id))
					break
		return adjacent_patch_ids
	for candidate_patch_state in patch_states:
		if candidate_patch_state == null or candidate_patch_state == patch_state or candidate_patch_state.current_quad == null:
			continue
		if not _shares_plane_and_normal(patch_state.current_quad, candidate_patch_state.current_quad):
			continue
		for candidate_edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
			var candidate_segment: Dictionary = _build_edge_segment(candidate_patch_state.current_quad, candidate_edge_id)
			if _segments_match(edge_segment, candidate_segment):
				_append_unique_patch_id(adjacent_patch_ids, String(candidate_patch_state.patch_id))
				break
	return adjacent_patch_ids

func _resolve_feature_bridge_neighbor_patch_ids(patch_state: Resource) -> PackedStringArray:
	if patch_state == null or patch_state.current_quad == null:
		return PackedStringArray()
	var adjacent_patch_ids: PackedStringArray = PackedStringArray()
	for candidate_patch_state in patch_states:
		if candidate_patch_state == null or candidate_patch_state == patch_state or candidate_patch_state.current_quad == null:
			continue
		if candidate_patch_state.zone_mask_id != patch_state.zone_mask_id:
			continue
		if is_zero_approx(resolve_current_offset_cells(candidate_patch_state)):
			continue
		if _shares_topology_plane_and_normal(patch_state, candidate_patch_state):
			continue
		if _patches_share_boundary_edge_across_topology(patch_state, candidate_patch_state):
			_append_unique_patch_id(adjacent_patch_ids, String(candidate_patch_state.patch_id))
	return adjacent_patch_ids

func _patch_has_feature_contour_transition(
	patch_lookup: Dictionary,
	patch_state: Resource,
	selected_lookup: Dictionary
) -> bool:
	if patch_state == null or patch_state.current_quad == null:
		return false
	var patch_offset_cells: float = resolve_current_offset_cells(patch_state)
	if is_zero_approx(patch_offset_cells):
		return false
	var adjacent_patch_ids: PackedStringArray = _resolve_boundary_neighbor_patch_ids(patch_state)
	for neighbor_patch_id_string: String in adjacent_patch_ids:
		var neighbor_patch_id: StringName = StringName(neighbor_patch_id_string)
		var neighbor_patch_state: Resource = patch_lookup.get(neighbor_patch_id, null)
		if neighbor_patch_state == null or neighbor_patch_state.current_quad == null:
			continue
		if not _shares_topology_plane_and_normal(patch_state, neighbor_patch_state):
			continue
		if neighbor_patch_state.zone_mask_id != patch_state.zone_mask_id:
			continue
		var neighbor_offset_cells: float = resolve_current_offset_cells(neighbor_patch_state)
		if not selected_lookup.has(neighbor_patch_id):
			if not is_equal_approx(neighbor_offset_cells, patch_offset_cells):
				return true
			continue
		if not is_equal_approx(neighbor_offset_cells, patch_offset_cells):
			return true
	return false

func _resolve_boundary_neighbor_patch_ids(patch_state: Resource) -> PackedStringArray:
	if patch_state == null or patch_state.current_quad == null:
		return PackedStringArray()
	var adjacent_patch_ids: PackedStringArray = PackedStringArray()
	if not patch_state.neighbor_patch_ids.is_empty():
		for neighbor_patch_id_string: String in patch_state.neighbor_patch_ids:
			_append_unique_patch_id(adjacent_patch_ids, neighbor_patch_id_string)
		return adjacent_patch_ids
	for candidate_patch_state in patch_states:
		if candidate_patch_state == null or candidate_patch_state == patch_state or candidate_patch_state.current_quad == null:
			continue
		if _patches_share_boundary_edge_by_topology(patch_state, candidate_patch_state):
			_append_unique_patch_id(adjacent_patch_ids, String(candidate_patch_state.patch_id))
	return adjacent_patch_ids

func _shares_topology_plane_and_normal(patch_state: Resource, candidate_patch_state: Resource) -> bool:
	var patch_quad: Resource = _get_topology_quad(patch_state)
	var candidate_quad: Resource = _get_topology_quad(candidate_patch_state)
	return _shares_plane_and_normal(patch_quad, candidate_quad)

func _patches_share_boundary_edge_by_topology(patch_state: Resource, candidate_patch_state: Resource) -> bool:
	var patch_quad: Resource = _get_topology_quad(patch_state)
	var candidate_quad: Resource = _get_topology_quad(candidate_patch_state)
	if patch_quad == null or candidate_quad == null:
		return false
	if not _shares_plane_and_normal(patch_quad, candidate_quad):
		return false
	for edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
		var patch_segment: Dictionary = _build_edge_segment(patch_quad, edge_id)
		for candidate_edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
			var candidate_segment: Dictionary = _build_edge_segment(candidate_quad, candidate_edge_id)
			if _segments_match(patch_segment, candidate_segment):
				return true
	return false

func _patches_share_boundary_edge_across_topology(patch_state: Resource, candidate_patch_state: Resource) -> bool:
	var patch_quad: Resource = _get_topology_quad(patch_state)
	var candidate_quad: Resource = _get_topology_quad(candidate_patch_state)
	if patch_quad == null or candidate_quad == null:
		return false
	for edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
		var patch_segment: Dictionary = _build_edge_segment(patch_quad, edge_id)
		for candidate_edge_id: StringName in [EDGE_U_MIN, EDGE_U_MAX, EDGE_V_MIN, EDGE_V_MAX]:
			var candidate_segment: Dictionary = _build_edge_segment(candidate_quad, candidate_edge_id)
			if _segments_match(patch_segment, candidate_segment):
				return true
	return false

func _get_topology_quad(patch_state: Resource) -> Resource:
	if patch_state == null:
		return null
	if patch_state.baseline_quad != null:
		return patch_state.baseline_quad
	return patch_state.current_quad

func _build_edge_segment(quad_state, edge_id: StringName) -> Dictionary:
	var origin_local: Vector3 = quad_state.origin_local
	var edge_u_local: Vector3 = quad_state.edge_u_local
	var edge_v_local: Vector3 = quad_state.edge_v_local
	match edge_id:
		EDGE_U_MIN:
			return {
				"start": origin_local,
				"end": origin_local + edge_v_local,
				"direction": edge_v_local.normalized(),
			}
		EDGE_U_MAX:
			return {
				"start": origin_local + edge_u_local,
				"end": origin_local + edge_u_local + edge_v_local,
				"direction": edge_v_local.normalized(),
			}
		EDGE_V_MIN:
			return {
				"start": origin_local,
				"end": origin_local + edge_u_local,
				"direction": edge_u_local.normalized(),
			}
		EDGE_V_MAX:
			return {
				"start": origin_local + edge_v_local,
				"end": origin_local + edge_u_local + edge_v_local,
				"direction": edge_u_local.normalized(),
			}
		_:
			return {
				"start": origin_local,
				"end": origin_local,
				"direction": Vector3.ZERO,
			}

func _segments_match(segment_a: Dictionary, segment_b: Dictionary) -> bool:
	var a_start: Vector3 = segment_a.get("start", Vector3.ZERO)
	var a_end: Vector3 = segment_a.get("end", Vector3.ZERO)
	var b_start: Vector3 = segment_b.get("start", Vector3.ZERO)
	var b_end: Vector3 = segment_b.get("end", Vector3.ZERO)
	return (
		(a_start.is_equal_approx(b_start) and a_end.is_equal_approx(b_end))
		or (a_start.is_equal_approx(b_end) and a_end.is_equal_approx(b_start))
	)

func _build_edge_segment_key(segment: Dictionary) -> String:
	var start_key: String = _build_vector3_key(segment.get("start", Vector3.ZERO))
	var end_key: String = _build_vector3_key(segment.get("end", Vector3.ZERO))
	if start_key <= end_key:
		return "%s|%s" % [start_key, end_key]
	return "%s|%s" % [end_key, start_key]

func _build_vector3_key(value: Vector3) -> String:
	return "%d_%d_%d" % [
		int(round(value.x * 1000.0)),
		int(round(value.y * 1000.0)),
		int(round(value.z * 1000.0))
	]

func _edges_share_same_line(base_segment: Dictionary, candidate_segment: Dictionary) -> bool:
	var base_direction: Vector3 = Vector3(base_segment.get("direction", Vector3.ZERO)).normalized()
	var candidate_direction: Vector3 = Vector3(candidate_segment.get("direction", Vector3.ZERO)).normalized()
	if base_direction == Vector3.ZERO or candidate_direction == Vector3.ZERO:
		return false
	var direction_alignment: float = absf(base_direction.dot(candidate_direction))
	if not is_equal_approx(direction_alignment, 1.0):
		return false
	var offset_vector: Vector3 = Vector3(candidate_segment.get("start", Vector3.ZERO)) - Vector3(base_segment.get("start", Vector3.ZERO))
	return offset_vector.cross(base_direction).length() <= 0.0001

func _resolve_edge_interval(segment: Dictionary, base_segment: Dictionary) -> Vector2:
	var base_direction: Vector3 = Vector3(base_segment.get("direction", Vector3.ZERO)).normalized()
	var base_start: Vector3 = base_segment.get("start", Vector3.ZERO)
	var segment_start: Vector3 = segment.get("start", Vector3.ZERO)
	var segment_end: Vector3 = segment.get("end", Vector3.ZERO)
	var start_scalar: float = (segment_start - base_start).dot(base_direction)
	var end_scalar: float = (segment_end - base_start).dot(base_direction)
	return Vector2(minf(start_scalar, end_scalar), maxf(start_scalar, end_scalar))

func _intervals_touch_or_overlap(interval_a: Vector2, interval_b: Vector2) -> bool:
	return interval_a.y >= interval_b.x - 0.0001 and interval_b.y >= interval_a.x - 0.0001

func _distance_point_to_segment(point: Vector3, segment_start: Vector3, segment_end: Vector3) -> float:
	var segment_vector: Vector3 = segment_end - segment_start
	var segment_length_squared: float = segment_vector.length_squared()
	if segment_length_squared <= 0.00001:
		return point.distance_to(segment_start)
	var ratio: float = clampf((point - segment_start).dot(segment_vector) / segment_length_squared, 0.0, 1.0)
	var closest_point: Vector3 = segment_start + (segment_vector * ratio)
	return point.distance_to(closest_point)

func set_patch_current_offset_cells(patch_state: Resource, next_offset_cells: float) -> bool:
	return set_shell_patch_offset_cells_for_patch(patch_state, next_offset_cells)

func set_shell_patch_offset_cells_for_patch_id(patch_id: StringName, next_offset_cells: float) -> bool:
	if patch_id == StringName():
		return false
	for patch_state in patch_states:
		if patch_state == null or patch_state.patch_id != patch_id:
			continue
		return set_shell_patch_offset_cells_for_patch(patch_state, next_offset_cells)
	return false

func set_shell_patch_offset_cells_for_patch(patch_state: Resource, next_offset_cells: float) -> bool:
	if patch_state == null:
		return false
	var clamped_offset_cells: float = maxf(next_offset_cells, 0.0)
	var shell_offset_data: Dictionary = _resolve_shell_patch_offset_data_for_patch(patch_state)
	if shell_offset_data.is_empty():
		var current_offset_cells_fallback: float = float(patch_state.get("current_offset_cells"))
		if is_equal_approx(current_offset_cells_fallback, clamped_offset_cells):
			return false
		patch_state.current_offset_cells = clamped_offset_cells
		_sync_patch_current_quad_from_offset_cells(patch_state, clamped_offset_cells)
		patch_state.dirty = true
		return true
	var current_offset_cells: float = float(shell_offset_data.get("value", 0.0))
	var shell_quad_state: Resource = shell_offset_data.get("shell_quad_state", null)
	var patch_offset_index: int = int(shell_offset_data.get("index", -1))
	var effective_current_offset_cells: float = current_offset_cells
	var current_geometry_offset_cells: float = _resolve_geometry_offset_cells(patch_state) if patch_state.baseline_quad != null and patch_state.current_quad != null else current_offset_cells
	var patch_stored_offset_cells: float = float(patch_state.get("current_offset_cells"))
	if not is_equal_approx(current_geometry_offset_cells, current_offset_cells):
		effective_current_offset_cells = current_geometry_offset_cells
	elif not is_equal_approx(patch_stored_offset_cells, current_offset_cells):
		effective_current_offset_cells = patch_stored_offset_cells
	if is_equal_approx(effective_current_offset_cells, clamped_offset_cells):
		if not is_equal_approx(current_offset_cells, clamped_offset_cells):
			var patch_offset_cells_stale: PackedFloat32Array = PackedFloat32Array(shell_quad_state.patch_offset_cells)
			if patch_offset_index >= 0 and patch_offset_index < patch_offset_cells_stale.size():
				patch_offset_cells_stale[patch_offset_index] = clamped_offset_cells
				shell_quad_state.patch_offset_cells = patch_offset_cells_stale
				patch_state.current_offset_cells = clamped_offset_cells
				_sync_patch_current_quad_from_offset_cells(patch_state, clamped_offset_cells)
				shell_quad_state.dirty = true
				patch_state.dirty = true
				return true
		return false
	if shell_quad_state == null or patch_offset_index < 0:
		return false
	var patch_offset_cells: PackedFloat32Array = PackedFloat32Array(shell_quad_state.patch_offset_cells)
	if patch_offset_index >= patch_offset_cells.size():
		return false
	patch_offset_cells[patch_offset_index] = clamped_offset_cells
	shell_quad_state.patch_offset_cells = patch_offset_cells
	shell_quad_state.dirty = true
	if current_shell_mesh_state != null:
		current_shell_mesh_state.dirty = true
	_sync_shell_vertex_offsets_from_patch_storage(shell_quad_state)
	patch_state.current_offset_cells = clamped_offset_cells
	_sync_patch_current_quad_from_offset_cells(patch_state, clamped_offset_cells)
	patch_state.dirty = true
	return true

func apply_shell_vertex_brush_delta_for_patch(
	patch_state: Resource,
	tool_id: StringName,
	hit_point_local: Vector3,
	tool_axis_local: Vector3,
	radius_cells: float,
	delta_cells: float,
	cell_size_meters: float
) -> bool:
	if patch_state == null or delta_cells <= 0.0 or radius_cells <= 0.0 or patch_state.shell_quad_id == StringName():
		return false
	var shell_quad_state: Resource = get_current_shell_quad_state_by_id(patch_state.shell_quad_id)
	if shell_quad_state == null:
		return false
	_ensure_shell_quad_vertex_offset_storage(shell_quad_state)
	var grid_u_index: int = int(patch_state.get("grid_u_index"))
	var grid_v_index: int = int(patch_state.get("grid_v_index"))
	var width_steps: int = maxi(shell_quad_state.width_voxels, 1)
	var height_steps: int = maxi(shell_quad_state.height_voxels, 1)
	var edge_u_step: Vector3 = shell_quad_state.edge_u_local / float(width_steps)
	var edge_v_step: Vector3 = shell_quad_state.edge_v_local / float(height_steps)
	var vertex_offset_cells: PackedFloat32Array = PackedFloat32Array(shell_quad_state.vertex_offset_cells)
	var shell_vertex_offsets_changed: bool = false
	for vertex_coords: Vector2i in [
		Vector2i(grid_u_index, grid_v_index),
		Vector2i(grid_u_index + 1, grid_v_index),
		Vector2i(grid_u_index, grid_v_index + 1),
		Vector2i(grid_u_index + 1, grid_v_index + 1),
	]:
		var vertex_offset_index: int = _resolve_shell_quad_vertex_offset_index(
			shell_quad_state,
			vertex_coords.x,
			vertex_coords.y
		)
		if vertex_offset_index < 0 or vertex_offset_index >= vertex_offset_cells.size():
			continue
		var vertex_local: Vector3 = _resolve_shell_vertex_local(
			shell_quad_state,
			vertex_coords.x,
			vertex_coords.y,
			edge_u_step,
			edge_v_step
		)
		var vertex_weight: float = _resolve_shell_vertex_brush_weight(
			vertex_local,
			hit_point_local,
			tool_axis_local,
			radius_cells
		)
		if vertex_weight <= 0.0:
			continue
		var effective_delta_cells: float = delta_cells * vertex_weight
		if effective_delta_cells <= 0.0:
			continue
		var current_vertex_offset_cells: float = float(vertex_offset_cells[vertex_offset_index])
		var next_vertex_offset_cells: float = current_vertex_offset_cells
		match tool_id:
			&"stage2_carve":
				next_vertex_offset_cells = minf(
					_resolve_shell_vertex_max_offset_cells(
						shell_quad_state,
						vertex_coords.x,
						vertex_coords.y,
						cell_size_meters
					),
					current_vertex_offset_cells + effective_delta_cells
				)
			&"stage2_restore":
				next_vertex_offset_cells = maxf(0.0, current_vertex_offset_cells - effective_delta_cells)
			_:
				return false
		if is_equal_approx(next_vertex_offset_cells, current_vertex_offset_cells):
			continue
		vertex_offset_cells[vertex_offset_index] = next_vertex_offset_cells
		shell_vertex_offsets_changed = true
	if not shell_vertex_offsets_changed:
		return false
	shell_quad_state.vertex_offset_cells = vertex_offset_cells
	shell_quad_state.dirty = true
	if current_shell_mesh_state != null:
		current_shell_mesh_state.dirty = true
	_sync_shell_patch_offsets_from_vertex_storage(shell_quad_state)
	dirty = true
	return true

func apply_shell_vertex_brush_delta_for_candidate_records(
	candidate_patch_records: Array[Dictionary],
	tool_id: StringName,
	hit_point_local: Vector3,
	tool_axis_local: Vector3,
	radius_cells: float,
	cell_size_meters: float
) -> bool:
	if candidate_patch_records.is_empty() or radius_cells <= 0.0:
		return false
	var shell_vertex_targets_by_key: Dictionary = {}
	for candidate_patch_record: Dictionary in candidate_patch_records:
		var patch_state: Resource = candidate_patch_record.get("patch_state", null)
		if patch_state == null or patch_state.shell_quad_id == StringName():
			continue
		var shell_quad_state: Resource = get_current_shell_quad_state_by_id(patch_state.shell_quad_id)
		if shell_quad_state == null:
			continue
		_ensure_shell_quad_vertex_offset_storage(shell_quad_state)
		var grid_u_index: int = int(candidate_patch_record.get("grid_u_index", int(patch_state.get("grid_u_index"))))
		var grid_v_index: int = int(candidate_patch_record.get("grid_v_index", int(patch_state.get("grid_v_index"))))
		var effective_delta_cells: float = float(candidate_patch_record.get("effective_delta_cells", 0.0))
		if effective_delta_cells <= 0.0:
			continue
		var width_steps: int = maxi(shell_quad_state.width_voxels, 1)
		var height_steps: int = maxi(shell_quad_state.height_voxels, 1)
		var edge_u_step: Vector3 = shell_quad_state.edge_u_local / float(width_steps)
		var edge_v_step: Vector3 = shell_quad_state.edge_v_local / float(height_steps)
		for vertex_coords: Vector2i in [
			Vector2i(grid_u_index, grid_v_index),
			Vector2i(grid_u_index + 1, grid_v_index),
			Vector2i(grid_u_index, grid_v_index + 1),
			Vector2i(grid_u_index + 1, grid_v_index + 1),
		]:
			var vertex_local: Vector3 = _resolve_shell_vertex_local(
				shell_quad_state,
				vertex_coords.x,
				vertex_coords.y,
				edge_u_step,
				edge_v_step
			)
			var vertex_weight: float = _resolve_shell_vertex_brush_weight(
				vertex_local,
				hit_point_local,
				tool_axis_local,
				radius_cells
			)
			if vertex_weight <= 0.0:
				continue
			var weighted_delta_cells: float = effective_delta_cells * vertex_weight
			if weighted_delta_cells <= 0.0:
				continue
			var shell_vertex_key: StringName = _resolve_shell_quad_vertex_key(
				shell_quad_state,
				vertex_coords.x,
				vertex_coords.y,
				edge_u_step,
				edge_v_step
			)
			if shell_vertex_key == StringName():
				continue
			var current_target: Dictionary = shell_vertex_targets_by_key.get(shell_vertex_key, {})
			var current_target_delta_cells: float = float(current_target.get("delta_cells", 0.0))
			var target_vertex_max_offset_cells: float = _resolve_shell_vertex_max_offset_cells(
				shell_quad_state,
				vertex_coords.x,
				vertex_coords.y,
				cell_size_meters
			)
			if current_target.is_empty():
				shell_vertex_targets_by_key[shell_vertex_key] = {
					"shell_quad_state": shell_quad_state,
					"vertex_u_index": vertex_coords.x,
					"vertex_v_index": vertex_coords.y,
					"delta_cells": weighted_delta_cells,
					"max_offset_cells": target_vertex_max_offset_cells,
					"edge_u_step": edge_u_step,
					"edge_v_step": edge_v_step,
				}
				continue
			current_target["delta_cells"] = maxf(current_target_delta_cells, weighted_delta_cells)
			current_target["max_offset_cells"] = minf(
				float(current_target.get("max_offset_cells", target_vertex_max_offset_cells)),
				target_vertex_max_offset_cells
			)
			shell_vertex_targets_by_key[shell_vertex_key] = current_target
	if shell_vertex_targets_by_key.is_empty():
		return false
	var changed_shell_quad_lookup: Dictionary = {}
	var changed_shared_vertex_delta_lookup: Dictionary = {}
	var shell_vertex_offsets_changed: bool = false
	for shell_vertex_target_key_variant in shell_vertex_targets_by_key.keys():
		var shell_vertex_target: Dictionary = shell_vertex_targets_by_key.get(shell_vertex_target_key_variant, {})
		var shell_quad_state: Resource = shell_vertex_target.get("shell_quad_state", null)
		if shell_quad_state == null:
			continue
		var edge_u_step: Vector3 = shell_vertex_target.get("edge_u_step", Vector3.ZERO)
		var edge_v_step: Vector3 = shell_vertex_target.get("edge_v_step", Vector3.ZERO)
		var vertex_u_index: int = int(shell_vertex_target.get("vertex_u_index", -1))
		var vertex_v_index: int = int(shell_vertex_target.get("vertex_v_index", -1))
		var current_vertex_local: Variant = _resolve_shell_shared_vertex_current_local(
			shell_quad_state,
			vertex_u_index,
			vertex_v_index,
			edge_u_step,
			edge_v_step
		)
		var baseline_vertex_local: Variant = _resolve_shell_shared_vertex_baseline_local(
			shell_quad_state,
			vertex_u_index,
			vertex_v_index,
			edge_u_step,
			edge_v_step
		)
		if current_vertex_local is not Vector3 or baseline_vertex_local is not Vector3:
			continue
		var resolved_current_vertex_local: Vector3 = current_vertex_local
		var resolved_baseline_vertex_local: Vector3 = baseline_vertex_local
		var target_delta_cells: float = float(shell_vertex_target.get("delta_cells", 0.0))
		var next_vertex_local: Vector3 = resolved_current_vertex_local
		match tool_id:
			&"stage2_carve":
				var carved_vertex_local: Vector3 = resolved_current_vertex_local + (tool_axis_local.normalized() * target_delta_cells)
				var baseline_delta: Vector3 = carved_vertex_local - resolved_baseline_vertex_local
				var max_offset_cells: float = float(shell_vertex_target.get("max_offset_cells", 0.0))
				if baseline_delta.length() > max_offset_cells and baseline_delta.length() > 0.00001:
					carved_vertex_local = resolved_baseline_vertex_local + (baseline_delta.normalized() * max_offset_cells)
				next_vertex_local = carved_vertex_local
			&"stage2_restore":
				var to_baseline: Vector3 = resolved_baseline_vertex_local - resolved_current_vertex_local
				if to_baseline.length() <= target_delta_cells:
					next_vertex_local = resolved_baseline_vertex_local
				else:
					next_vertex_local = resolved_current_vertex_local + (to_baseline.normalized() * target_delta_cells)
			_:
				return false
		if resolved_current_vertex_local.is_equal_approx(next_vertex_local):
			continue
		if not _set_shell_shared_vertex_current_local(
			shell_quad_state,
			vertex_u_index,
			vertex_v_index,
			next_vertex_local,
			edge_u_step,
			edge_v_step
		):
			continue
		for changed_shell_quad_id_string: String in _resolve_shell_quad_ids_for_shared_vertex_key(
			StringName(shell_vertex_target_key_variant)
		):
			var changed_shell_quad_id: StringName = StringName(changed_shell_quad_id_string)
			var changed_shell_quad_state: Resource = get_current_shell_quad_state_by_id(changed_shell_quad_id)
			if changed_shell_quad_state == null:
				continue
			changed_shell_quad_lookup[changed_shell_quad_id] = changed_shell_quad_state
		changed_shared_vertex_delta_lookup[StringName(shell_vertex_target_key_variant)] = (
			next_vertex_local - resolved_current_vertex_local
		)
		shell_vertex_offsets_changed = true
	if not shell_vertex_offsets_changed:
		return false
	if tool_id == &"stage2_carve" or tool_id == &"stage2_restore":
		_apply_shared_vertex_neighbor_ring_relaxation(
			changed_shared_vertex_delta_lookup,
			cell_size_meters,
			changed_shell_quad_lookup
		)
	if current_shell_mesh_state != null:
		current_shell_mesh_state.dirty = true
	for changed_shell_quad_id: StringName in changed_shell_quad_lookup.keys():
		_sync_shell_patch_offsets_from_vertex_storage(changed_shell_quad_lookup[changed_shell_quad_id])
	dirty = true
	return true

func _resolve_shell_vertex_brush_weight(
	vertex_local: Vector3,
	hit_point_local: Vector3,
	tool_axis_local: Vector3,
	radius_cells: float
) -> float:
	if radius_cells <= 0.0:
		return 0.0
	var effective_radius_cells: float = maxf(radius_cells, 0.75)
	var normalized_axis: Vector3 = tool_axis_local.normalized()
	var relative_vertex: Vector3 = vertex_local - hit_point_local
	var lateral_distance_cells: float = 0.0
	if normalized_axis == Vector3.ZERO:
		lateral_distance_cells = relative_vertex.length()
	else:
		var lateral_delta: Vector3 = relative_vertex - (normalized_axis * relative_vertex.dot(normalized_axis))
		lateral_distance_cells = lateral_delta.length()
	if lateral_distance_cells > effective_radius_cells:
		return 0.0
	return 1.0 - clampf(lateral_distance_cells / effective_radius_cells, 0.0, 1.0)

func _resolve_geometry_offset_cells(patch_state: Resource) -> float:
	if patch_state == null or patch_state.baseline_quad == null or patch_state.current_quad == null:
		return 0.0
	var normal: Vector3 = patch_state.current_quad.normal.normalized()
	if normal == Vector3.ZERO:
		return 0.0
	return (patch_state.baseline_quad.origin_local - patch_state.current_quad.origin_local).dot(normal)

func _sync_patch_current_quad_from_offset_cells(patch_state: Resource, offset_cells: float) -> void:
	if patch_state == null or patch_state.baseline_quad == null or patch_state.current_quad == null:
		return
	var normal: Vector3 = patch_state.current_quad.normal.normalized()
	if normal == Vector3.ZERO:
		normal = patch_state.baseline_quad.normal.normalized()
	if normal == Vector3.ZERO:
		return
	patch_state.current_quad.origin_local = patch_state.baseline_quad.origin_local - (normal * maxf(offset_cells, 0.0))

func _shares_plane_and_normal(quad_a: Resource, quad_b: Resource) -> bool:
	if quad_a == null or quad_b == null:
		return false
	var normal_a: Vector3 = quad_a.normal.normalized()
	var normal_b: Vector3 = quad_b.normal.normalized()
	if not normal_a.is_equal_approx(normal_b):
		return false
	return is_equal_approx(normal_a.dot(quad_a.origin_local), normal_b.dot(quad_b.origin_local))

func _is_patch_state_overridden(patch_state: Resource) -> bool:
	if patch_state == null or patch_state.baseline_quad == null or patch_state.current_quad == null:
		return false
	return not _quad_states_match(patch_state.baseline_quad, patch_state.current_quad)

func _quad_states_match(left_quad: Resource, right_quad: Resource) -> bool:
	return (
		left_quad.origin_local.is_equal_approx(right_quad.origin_local)
		and left_quad.edge_u_local.is_equal_approx(right_quad.edge_u_local)
		and left_quad.edge_v_local.is_equal_approx(right_quad.edge_v_local)
		and left_quad.normal.is_equal_approx(right_quad.normal)
		and left_quad.material_variant_id == right_quad.material_variant_id
		and left_quad.shell_quad_id == right_quad.shell_quad_id
		and left_quad.width_voxels == right_quad.width_voxels
		and left_quad.height_voxels == right_quad.height_voxels
	)

func _build_shell_patch_offset_lookup(shell_quad_state: Resource) -> Dictionary:
	var patch_offset_lookup: Dictionary = {}
	_ensure_shell_quad_patch_offset_storage(shell_quad_state)
	var width_steps: int = maxi(shell_quad_state.width_voxels, 1)
	var height_steps: int = maxi(shell_quad_state.height_voxels, 1)
	var patch_offset_cells: PackedFloat32Array = shell_quad_state.patch_offset_cells
	for v_index: int in range(height_steps):
		for u_index: int in range(width_steps):
			var patch_offset_index: int = _resolve_shell_quad_patch_offset_index(shell_quad_state, u_index, v_index)
			if patch_offset_index < 0 or patch_offset_index >= patch_offset_cells.size():
				continue
			patch_offset_lookup[Vector2i(u_index, v_index)] = float(patch_offset_cells[patch_offset_index])
	return patch_offset_lookup

func _build_changed_patch_coord_lookup(shell_quad_state: Resource) -> Dictionary:
	var changed_patch_coord_lookup: Dictionary = {}
	if shell_quad_state == null:
		return changed_patch_coord_lookup
	_ensure_shell_quad_patch_offset_storage(shell_quad_state)
	var width_steps: int = maxi(shell_quad_state.width_voxels, 1)
	var height_steps: int = maxi(shell_quad_state.height_voxels, 1)
	var patch_offset_cells: PackedFloat32Array = shell_quad_state.patch_offset_cells
	for v_index: int in range(height_steps):
		for u_index: int in range(width_steps):
			var patch_offset_index: int = _resolve_shell_quad_patch_offset_index(shell_quad_state, u_index, v_index)
			if patch_offset_index < 0 or patch_offset_index >= patch_offset_cells.size():
				continue
			if is_zero_approx(float(patch_offset_cells[patch_offset_index])):
				continue
			changed_patch_coord_lookup[Vector2i(u_index, v_index)] = true
	return changed_patch_coord_lookup

func _shell_quad_has_deformation(shell_quad_state: Resource, _shell_patch_states: Array = []) -> bool:
	if shell_quad_state == null:
		return false
	return not _build_changed_patch_coord_lookup(shell_quad_state).is_empty()

func _shell_cell_has_shared_vertex_deformation(
	shell_quad_state: Resource,
	u_index: int,
	v_index: int,
	edge_u_step: Vector3,
	edge_v_step: Vector3
) -> bool:
	if shell_quad_state == null:
		return false
	for vertex_coords: Vector2i in [
		Vector2i(u_index, v_index),
		Vector2i(u_index + 1, v_index),
		Vector2i(u_index, v_index + 1),
		Vector2i(u_index + 1, v_index + 1),
	]:
		var current_vertex_local: Variant = _resolve_shell_shared_vertex_current_local(
			shell_quad_state,
			vertex_coords.x,
			vertex_coords.y,
			edge_u_step,
			edge_v_step
		)
		var baseline_vertex_local: Variant = _resolve_shell_shared_vertex_baseline_local(
			shell_quad_state,
			vertex_coords.x,
			vertex_coords.y,
			edge_u_step,
			edge_v_step
		)
		if current_vertex_local is not Vector3 or baseline_vertex_local is not Vector3:
			continue
		if not current_vertex_local.is_equal_approx(baseline_vertex_local):
			return true
	return false

func _ensure_shell_offset_storage_for_geometry_build() -> void:
	if not has_unified_shell():
		return
	_ensure_shell_shared_vertex_storage()
	var patch_states_by_shell_quad_id: Dictionary = _build_patch_states_by_shell_quad_id()
	for shell_quad_state: Resource in current_shell_mesh_state.shell_quads:
		if shell_quad_state == null or shell_quad_state.shell_quad_id == StringName():
			continue
		_ensure_shell_quad_patch_offset_storage(
			shell_quad_state,
			patch_states_by_shell_quad_id.get(shell_quad_state.shell_quad_id, [])
		)
		_ensure_shell_quad_vertex_offset_storage(
			shell_quad_state,
			patch_states_by_shell_quad_id.get(shell_quad_state.shell_quad_id, [])
		)

func _build_shared_shell_vertex_key(vertex_local: Vector3) -> StringName:
	return StringName("%d::%d::%d" % [
		int(round(vertex_local.x * 10000.0)),
		int(round(vertex_local.y * 10000.0)),
		int(round(vertex_local.z * 10000.0)),
	])

func _resolve_shell_quad_vertex_key_index(shell_quad_state: Resource, u_index: int, v_index: int) -> int:
	if shell_quad_state == null:
		return -1
	var width_steps: int = maxi(shell_quad_state.width_voxels, 1)
	var height_steps: int = maxi(shell_quad_state.height_voxels, 1)
	if u_index < 0 or u_index > width_steps or v_index < 0 or v_index > height_steps:
		return -1
	return (v_index * (width_steps + 1)) + u_index

func _resolve_shared_vertex_index_lookup() -> Dictionary:
	if current_shell_mesh_state == null:
		return {}
	if current_shell_mesh_state.has_meta("_shared_vertex_index_lookup"):
		return current_shell_mesh_state.get_meta("_shared_vertex_index_lookup")
	var shared_vertex_lookup: Dictionary = {}
	for shared_vertex_index: int in range(current_shell_mesh_state.shared_vertex_keys.size()):
		shared_vertex_lookup[StringName(current_shell_mesh_state.shared_vertex_keys[shared_vertex_index])] = shared_vertex_index
	current_shell_mesh_state.set_meta("_shared_vertex_index_lookup", shared_vertex_lookup)
	return shared_vertex_lookup

func _invalidate_shared_vertex_index_lookup_cache() -> void:
	if current_shell_mesh_state == null:
		return
	for cache_meta_name in [
		"_shared_vertex_index_lookup",
		"_shared_vertex_owner_records_lookup",
		"_shared_vertex_neighbor_keys_lookup",
		"_shared_vertex_max_offset_lookup_key",
		"_shared_vertex_max_offset_lookup",
	]:
		if current_shell_mesh_state.has_meta(cache_meta_name):
			current_shell_mesh_state.remove_meta(cache_meta_name)

func _resolve_shared_vertex_owner_records_lookup() -> Dictionary:
	if current_shell_mesh_state == null:
		return {}
	if current_shell_mesh_state.has_meta("_shared_vertex_owner_records_lookup"):
		return current_shell_mesh_state.get_meta("_shared_vertex_owner_records_lookup")
	var owner_records_lookup: Dictionary = {}
	for shell_quad_state: Resource in current_shell_mesh_state.shell_quads:
		if shell_quad_state == null or shell_quad_state.shell_quad_id == StringName():
			continue
		var width_steps: int = maxi(shell_quad_state.width_voxels, 1)
		var row_width: int = width_steps + 1
		for vertex_index: int in range(shell_quad_state.vertex_keys.size()):
			var shared_vertex_key: StringName = StringName(shell_quad_state.vertex_keys[vertex_index])
			if shared_vertex_key == StringName():
				continue
			var owner_records: Array = owner_records_lookup.get(shared_vertex_key, [])
			owner_records.append({
				"shell_quad_id": shell_quad_state.shell_quad_id,
				"vertex_u_index": vertex_index % row_width,
				"vertex_v_index": int(floor(float(vertex_index) / float(row_width))),
			})
			owner_records_lookup[shared_vertex_key] = owner_records
	current_shell_mesh_state.set_meta("_shared_vertex_owner_records_lookup", owner_records_lookup)
	return owner_records_lookup

func _resolve_shell_quad_vertex_key(
	shell_quad_state: Resource,
	u_index: int,
	v_index: int,
	edge_u_step: Vector3 = Vector3.ZERO,
	edge_v_step: Vector3 = Vector3.ZERO
) -> StringName:
	if shell_quad_state == null:
		return StringName()
	var vertex_key_index: int = _resolve_shell_quad_vertex_key_index(shell_quad_state, u_index, v_index)
	if vertex_key_index >= 0 and vertex_key_index < shell_quad_state.vertex_keys.size():
		var stored_vertex_key: StringName = StringName(shell_quad_state.vertex_keys[vertex_key_index])
		if stored_vertex_key != StringName():
			return stored_vertex_key
	if edge_u_step == Vector3.ZERO or edge_v_step == Vector3.ZERO:
		var width_steps: int = maxi(shell_quad_state.width_voxels, 1)
		var height_steps: int = maxi(shell_quad_state.height_voxels, 1)
		edge_u_step = shell_quad_state.edge_u_local / float(width_steps)
		edge_v_step = shell_quad_state.edge_v_local / float(height_steps)
	var baseline_vertex: Vector3 = (
		shell_quad_state.origin_local
		+ (edge_u_step * float(u_index))
		+ (edge_v_step * float(v_index))
	)
	return _build_shared_shell_vertex_key(baseline_vertex)

func _ensure_shell_shared_vertex_storage() -> void:
	if current_shell_mesh_state == null:
		return
	var shared_vertex_keys: PackedStringArray = PackedStringArray(current_shell_mesh_state.shared_vertex_keys)
	var shared_vertex_baseline_positions_local: PackedVector3Array = PackedVector3Array(current_shell_mesh_state.shared_vertex_baseline_positions_local)
	var shared_vertex_current_positions_local: PackedVector3Array = PackedVector3Array(current_shell_mesh_state.shared_vertex_current_positions_local)
	var expected_shell_vertex_count: int = 0
	for shell_quad_state: Resource in current_shell_mesh_state.shell_quads:
		if shell_quad_state == null:
			continue
		expected_shell_vertex_count += (maxi(shell_quad_state.width_voxels, 1) + 1) * (maxi(shell_quad_state.height_voxels, 1) + 1)
	var needs_rebuild: bool = (
		shared_vertex_keys.is_empty()
		or shared_vertex_keys.size() != shared_vertex_baseline_positions_local.size()
		or shared_vertex_keys.size() != shared_vertex_current_positions_local.size()
	)
	if not needs_rebuild:
		var stored_shell_vertex_count: int = 0
		for shell_quad_state: Resource in current_shell_mesh_state.shell_quads:
			if shell_quad_state == null:
				continue
			stored_shell_vertex_count += shell_quad_state.vertex_keys.size()
		needs_rebuild = stored_shell_vertex_count != expected_shell_vertex_count
	if not needs_rebuild:
		return
	var shared_vertex_lookup: Dictionary = {}
	var shared_vertex_position_sums: Array[Vector3] = []
	var shared_vertex_sample_counts: PackedInt32Array = PackedInt32Array()
	shared_vertex_keys = PackedStringArray()
	shared_vertex_baseline_positions_local = PackedVector3Array()
	shared_vertex_current_positions_local = PackedVector3Array()
	for shell_quad_state: Resource in current_shell_mesh_state.shell_quads:
		if shell_quad_state == null:
			continue
		var width_steps: int = maxi(shell_quad_state.width_voxels, 1)
		var height_steps: int = maxi(shell_quad_state.height_voxels, 1)
		var edge_u_step: Vector3 = shell_quad_state.edge_u_local / float(width_steps)
		var edge_v_step: Vector3 = shell_quad_state.edge_v_local / float(height_steps)
		var vertex_keys: PackedStringArray = PackedStringArray()
		vertex_keys.resize((width_steps + 1) * (height_steps + 1))
		for vertex_v_index: int in range(height_steps + 1):
			for vertex_u_index: int in range(width_steps + 1):
				var baseline_vertex: Vector3 = (
					shell_quad_state.origin_local
					+ (edge_u_step * float(vertex_u_index))
					+ (edge_v_step * float(vertex_v_index))
				)
				var current_vertex: Vector3 = _resolve_shell_vertex_local_from_per_quad_offsets(
					shell_quad_state,
					vertex_u_index,
					vertex_v_index,
					edge_u_step,
					edge_v_step
				)
				var shared_vertex_key: StringName = _build_shared_shell_vertex_key(baseline_vertex)
				var shared_vertex_index: int = int(shared_vertex_lookup.get(shared_vertex_key, -1))
				if shared_vertex_index == -1:
					shared_vertex_index = shared_vertex_keys.size()
					shared_vertex_lookup[shared_vertex_key] = shared_vertex_index
					shared_vertex_keys.append(String(shared_vertex_key))
					shared_vertex_baseline_positions_local.append(baseline_vertex)
					shared_vertex_current_positions_local.append(current_vertex)
					shared_vertex_position_sums.append(current_vertex)
					shared_vertex_sample_counts.append(1)
				else:
					shared_vertex_position_sums[shared_vertex_index] = shared_vertex_position_sums[shared_vertex_index] + current_vertex
					shared_vertex_sample_counts[shared_vertex_index] = int(shared_vertex_sample_counts[shared_vertex_index]) + 1
				var vertex_key_index: int = _resolve_shell_quad_vertex_key_index(
					shell_quad_state,
					vertex_u_index,
					vertex_v_index
				)
				vertex_keys[vertex_key_index] = String(shared_vertex_key)
		shell_quad_state.vertex_keys = vertex_keys
	for shared_vertex_index: int in range(shared_vertex_keys.size()):
		var sample_count: int = int(shared_vertex_sample_counts[shared_vertex_index])
		if sample_count <= 1:
			continue
		shared_vertex_current_positions_local[shared_vertex_index] = (
			shared_vertex_position_sums[shared_vertex_index] / float(sample_count)
		)
	current_shell_mesh_state.shared_vertex_keys = shared_vertex_keys
	current_shell_mesh_state.shared_vertex_baseline_positions_local = shared_vertex_baseline_positions_local
	current_shell_mesh_state.shared_vertex_current_positions_local = shared_vertex_current_positions_local
	_invalidate_shared_vertex_index_lookup_cache()

func _resolve_shell_vertex_local_from_per_quad_offsets(
	shell_quad_state: Resource,
	u_index: int,
	v_index: int,
	edge_u_step: Vector3,
	edge_v_step: Vector3,
	fallback_patch_offset_lookup: Dictionary = {}
) -> Vector3:
	if shell_quad_state == null:
		return Vector3.ZERO
	var shell_normal: Vector3 = shell_quad_state.normal.normalized()
	var baseline_vertex: Vector3 = (
		shell_quad_state.origin_local
		+ (edge_u_step * float(u_index))
		+ (edge_v_step * float(v_index))
	)
	return baseline_vertex - (
		shell_normal
		* _resolve_shell_vertex_offset_cells(shell_quad_state, u_index, v_index, fallback_patch_offset_lookup)
	)

func _resolve_shell_shared_vertex_current_local(
	shell_quad_state: Resource,
	u_index: int,
	v_index: int,
	edge_u_step: Vector3 = Vector3.ZERO,
	edge_v_step: Vector3 = Vector3.ZERO
) -> Variant:
	if current_shell_mesh_state == null or shell_quad_state == null:
		return null
	_ensure_shell_shared_vertex_storage()
	var shared_vertex_key: StringName = _resolve_shell_quad_vertex_key(
		shell_quad_state,
		u_index,
		v_index,
		edge_u_step,
		edge_v_step
	)
	if shared_vertex_key == StringName():
		return null
	var shared_vertex_lookup: Dictionary = _resolve_shared_vertex_index_lookup()
	var shared_vertex_index: int = int(shared_vertex_lookup.get(shared_vertex_key, -1))
	if shared_vertex_index < 0 or shared_vertex_index >= current_shell_mesh_state.shared_vertex_current_positions_local.size():
		return null
	return current_shell_mesh_state.shared_vertex_current_positions_local[shared_vertex_index]

func _resolve_shell_shared_vertex_baseline_local(
	shell_quad_state: Resource,
	u_index: int,
	v_index: int,
	edge_u_step: Vector3 = Vector3.ZERO,
	edge_v_step: Vector3 = Vector3.ZERO
) -> Variant:
	if current_shell_mesh_state == null or shell_quad_state == null:
		return null
	_ensure_shell_shared_vertex_storage()
	var shared_vertex_key: StringName = _resolve_shell_quad_vertex_key(
		shell_quad_state,
		u_index,
		v_index,
		edge_u_step,
		edge_v_step
	)
	if shared_vertex_key == StringName():
		return null
	var shared_vertex_lookup: Dictionary = _resolve_shared_vertex_index_lookup()
	var shared_vertex_index: int = int(shared_vertex_lookup.get(shared_vertex_key, -1))
	if shared_vertex_index < 0 or shared_vertex_index >= current_shell_mesh_state.shared_vertex_baseline_positions_local.size():
		return null
	return current_shell_mesh_state.shared_vertex_baseline_positions_local[shared_vertex_index]

func _set_shell_shared_vertex_current_local(
	shell_quad_state: Resource,
	u_index: int,
	v_index: int,
	next_vertex_local: Vector3,
	edge_u_step: Vector3 = Vector3.ZERO,
	edge_v_step: Vector3 = Vector3.ZERO
) -> bool:
	if current_shell_mesh_state == null or shell_quad_state == null:
		return false
	_ensure_shell_shared_vertex_storage()
	var shared_vertex_key: StringName = _resolve_shell_quad_vertex_key(
		shell_quad_state,
		u_index,
		v_index,
		edge_u_step,
		edge_v_step
	)
	if shared_vertex_key == StringName():
		return false
	var shared_vertex_lookup: Dictionary = _resolve_shared_vertex_index_lookup()
	var shared_vertex_index: int = int(shared_vertex_lookup.get(shared_vertex_key, -1))
	if shared_vertex_index < 0 or shared_vertex_index >= current_shell_mesh_state.shared_vertex_current_positions_local.size():
		return false
	var current_positions: PackedVector3Array = PackedVector3Array(current_shell_mesh_state.shared_vertex_current_positions_local)
	if current_positions[shared_vertex_index].is_equal_approx(next_vertex_local):
		return false
	current_positions[shared_vertex_index] = next_vertex_local
	current_shell_mesh_state.shared_vertex_current_positions_local = current_positions
	current_shell_mesh_state.dirty = true
	return true

func _resolve_shared_vertex_current_local_by_key(shared_vertex_key: StringName) -> Variant:
	if current_shell_mesh_state == null or shared_vertex_key == StringName():
		return null
	_ensure_shell_shared_vertex_storage()
	var shared_vertex_lookup: Dictionary = _resolve_shared_vertex_index_lookup()
	var shared_vertex_index: int = int(shared_vertex_lookup.get(shared_vertex_key, -1))
	if shared_vertex_index < 0 or shared_vertex_index >= current_shell_mesh_state.shared_vertex_current_positions_local.size():
		return null
	return current_shell_mesh_state.shared_vertex_current_positions_local[shared_vertex_index]

func _resolve_shared_vertex_baseline_local_by_key(shared_vertex_key: StringName) -> Variant:
	if current_shell_mesh_state == null or shared_vertex_key == StringName():
		return null
	_ensure_shell_shared_vertex_storage()
	var shared_vertex_lookup: Dictionary = _resolve_shared_vertex_index_lookup()
	var shared_vertex_index: int = int(shared_vertex_lookup.get(shared_vertex_key, -1))
	if shared_vertex_index < 0 or shared_vertex_index >= current_shell_mesh_state.shared_vertex_baseline_positions_local.size():
		return null
	return current_shell_mesh_state.shared_vertex_baseline_positions_local[shared_vertex_index]

func _set_shared_vertex_current_local_by_key(shared_vertex_key: StringName, next_vertex_local: Vector3) -> bool:
	if current_shell_mesh_state == null or shared_vertex_key == StringName():
		return false
	_ensure_shell_shared_vertex_storage()
	var shared_vertex_lookup: Dictionary = _resolve_shared_vertex_index_lookup()
	var shared_vertex_index: int = int(shared_vertex_lookup.get(shared_vertex_key, -1))
	if shared_vertex_index < 0 or shared_vertex_index >= current_shell_mesh_state.shared_vertex_current_positions_local.size():
		return false
	var current_positions: PackedVector3Array = PackedVector3Array(current_shell_mesh_state.shared_vertex_current_positions_local)
	if current_positions[shared_vertex_index].is_equal_approx(next_vertex_local):
		return false
	current_positions[shared_vertex_index] = next_vertex_local
	current_shell_mesh_state.shared_vertex_current_positions_local = current_positions
	current_shell_mesh_state.dirty = true
	return true

func _resolve_shared_shell_vertex_neighbor_keys(shared_vertex_key: StringName) -> PackedStringArray:
	if current_shell_mesh_state == null or shared_vertex_key == StringName():
		return PackedStringArray()
	if not current_shell_mesh_state.has_meta("_shared_vertex_neighbor_keys_lookup"):
		var neighbor_lookup: Dictionary = {}
		var neighbor_sets: Dictionary = {}
		for shell_quad_state: Resource in current_shell_mesh_state.shell_quads:
			if shell_quad_state == null:
				continue
			var width_steps: int = maxi(shell_quad_state.width_voxels, 1)
			var height_steps: int = maxi(shell_quad_state.height_voxels, 1)
			for vertex_v_index: int in range(height_steps + 1):
				for vertex_u_index: int in range(width_steps + 1):
					var vertex_index: int = _resolve_shell_quad_vertex_key_index(shell_quad_state, vertex_u_index, vertex_v_index)
					if vertex_index < 0 or vertex_index >= shell_quad_state.vertex_keys.size():
						continue
					var origin_key: StringName = StringName(shell_quad_state.vertex_keys[vertex_index])
					if origin_key == StringName():
						continue
					var origin_neighbor_set: Dictionary = neighbor_sets.get(origin_key, {})
					for neighbor_offset: Vector2i in [
						Vector2i(-1, 0),
						Vector2i(1, 0),
						Vector2i(0, -1),
						Vector2i(0, 1),
					]:
						var neighbor_u_index: int = vertex_u_index + neighbor_offset.x
						var neighbor_v_index: int = vertex_v_index + neighbor_offset.y
						if neighbor_u_index < 0 or neighbor_u_index > width_steps or neighbor_v_index < 0 or neighbor_v_index > height_steps:
							continue
						var neighbor_index: int = _resolve_shell_quad_vertex_key_index(
							shell_quad_state,
							neighbor_u_index,
							neighbor_v_index
						)
						if neighbor_index < 0 or neighbor_index >= shell_quad_state.vertex_keys.size():
							continue
						var neighbor_key: StringName = StringName(shell_quad_state.vertex_keys[neighbor_index])
						if neighbor_key == StringName() or neighbor_key == origin_key:
							continue
						origin_neighbor_set[neighbor_key] = true
					neighbor_sets[origin_key] = origin_neighbor_set
		for origin_key_variant in neighbor_sets.keys():
			var packed_neighbor_keys: PackedStringArray = PackedStringArray()
			var origin_neighbor_set: Dictionary = neighbor_sets.get(origin_key_variant, {})
			for neighbor_key_variant in origin_neighbor_set.keys():
				packed_neighbor_keys.append(String(neighbor_key_variant))
			neighbor_lookup[StringName(origin_key_variant)] = packed_neighbor_keys
		current_shell_mesh_state.set_meta("_shared_vertex_neighbor_keys_lookup", neighbor_lookup)
	var resolved_neighbor_lookup: Dictionary = current_shell_mesh_state.get_meta("_shared_vertex_neighbor_keys_lookup")
	return PackedStringArray(resolved_neighbor_lookup.get(shared_vertex_key, PackedStringArray()))

func _resolve_shared_shell_vertex_max_offset_cells(shared_vertex_key: StringName, cell_size_meters: float) -> float:
	if current_shell_mesh_state == null or shared_vertex_key == StringName():
		return 0.0
	var cache_key: int = int(round(cell_size_meters * 100000.0))
	if current_shell_mesh_state.has_meta("_shared_vertex_max_offset_lookup_key") and current_shell_mesh_state.has_meta("_shared_vertex_max_offset_lookup"):
		if int(current_shell_mesh_state.get_meta("_shared_vertex_max_offset_lookup_key")) == cache_key:
			var cached_max_offset_lookup: Dictionary = current_shell_mesh_state.get_meta("_shared_vertex_max_offset_lookup")
			return float(cached_max_offset_lookup.get(shared_vertex_key, 0.0))
	var max_offset_lookup: Dictionary = {}
	var owner_records_lookup: Dictionary = _resolve_shared_vertex_owner_records_lookup()
	for shared_vertex_key_variant in owner_records_lookup.keys():
		var owner_records: Array = owner_records_lookup.get(shared_vertex_key_variant, [])
		var has_owner: bool = false
		var resolved_max_offset_cells: float = 0.0
		for owner_record_variant in owner_records:
			var owner_record: Dictionary = owner_record_variant
			var shell_quad_state: Resource = get_current_shell_quad_state_by_id(StringName(owner_record.get("shell_quad_id", StringName())))
			if shell_quad_state == null:
				continue
			var owner_max_offset_cells: float = _resolve_shell_vertex_max_offset_cells(
				shell_quad_state,
				int(owner_record.get("vertex_u_index", -1)),
				int(owner_record.get("vertex_v_index", -1)),
				cell_size_meters
			)
			if not has_owner:
				resolved_max_offset_cells = owner_max_offset_cells
				has_owner = true
				continue
			resolved_max_offset_cells = minf(resolved_max_offset_cells, owner_max_offset_cells)
		max_offset_lookup[StringName(shared_vertex_key_variant)] = maxf(resolved_max_offset_cells, 0.0) if has_owner else 0.0
	current_shell_mesh_state.set_meta("_shared_vertex_max_offset_lookup_key", cache_key)
	current_shell_mesh_state.set_meta("_shared_vertex_max_offset_lookup", max_offset_lookup)
	return float(max_offset_lookup.get(shared_vertex_key, 0.0))

func _apply_shared_vertex_neighbor_ring_relaxation(
	changed_shared_vertex_delta_lookup: Dictionary,
	cell_size_meters: float,
	changed_shell_quad_lookup: Dictionary
) -> void:
	if changed_shared_vertex_delta_lookup.is_empty():
		return
	var neighbor_delta_sums: Dictionary = {}
	var neighbor_delta_counts: Dictionary = {}
	for shared_vertex_key_variant in changed_shared_vertex_delta_lookup.keys():
		var shared_vertex_key: StringName = StringName(shared_vertex_key_variant)
		var primary_delta: Vector3 = changed_shared_vertex_delta_lookup.get(shared_vertex_key_variant, Vector3.ZERO)
		if primary_delta.is_zero_approx():
			continue
		for neighbor_key_string: String in _resolve_shared_shell_vertex_neighbor_keys(shared_vertex_key):
			var neighbor_key: StringName = StringName(neighbor_key_string)
			if neighbor_key == StringName() or changed_shared_vertex_delta_lookup.has(neighbor_key):
				continue
			var softened_delta: Vector3 = primary_delta * 0.35
			neighbor_delta_sums[neighbor_key] = neighbor_delta_sums.get(neighbor_key, Vector3.ZERO) + softened_delta
			neighbor_delta_counts[neighbor_key] = int(neighbor_delta_counts.get(neighbor_key, 0)) + 1
	for neighbor_key_variant in neighbor_delta_sums.keys():
		var neighbor_key: StringName = StringName(neighbor_key_variant)
		var current_vertex_local: Variant = _resolve_shared_vertex_current_local_by_key(neighbor_key)
		var baseline_vertex_local: Variant = _resolve_shared_vertex_baseline_local_by_key(neighbor_key)
		if current_vertex_local is not Vector3 or baseline_vertex_local is not Vector3:
			continue
		var averaged_delta: Vector3 = neighbor_delta_sums[neighbor_key_variant] / float(maxi(int(neighbor_delta_counts.get(neighbor_key_variant, 1)), 1))
		if averaged_delta.is_zero_approx():
			continue
		var resolved_current_vertex_local: Vector3 = current_vertex_local
		var resolved_baseline_vertex_local: Vector3 = baseline_vertex_local
		var next_vertex_local: Vector3 = resolved_current_vertex_local + averaged_delta
		var max_offset_cells: float = _resolve_shared_shell_vertex_max_offset_cells(neighbor_key, cell_size_meters)
		var baseline_delta: Vector3 = next_vertex_local - resolved_baseline_vertex_local
		if max_offset_cells > 0.0 and baseline_delta.length() > max_offset_cells and baseline_delta.length() > 0.00001:
			next_vertex_local = resolved_baseline_vertex_local + (baseline_delta.normalized() * max_offset_cells)
		if not _set_shared_vertex_current_local_by_key(neighbor_key, next_vertex_local):
			continue
		for changed_shell_quad_id_string: String in _resolve_shell_quad_ids_for_shared_vertex_key(neighbor_key):
			var changed_shell_quad_id: StringName = StringName(changed_shell_quad_id_string)
			var changed_shell_quad_state: Resource = get_current_shell_quad_state_by_id(changed_shell_quad_id)
			if changed_shell_quad_state == null:
				continue
			changed_shell_quad_lookup[changed_shell_quad_id] = changed_shell_quad_state

func _resolve_shell_quad_ids_for_shared_vertex_key(shared_vertex_key: StringName) -> PackedStringArray:
	var shell_quad_ids: PackedStringArray = PackedStringArray()
	if current_shell_mesh_state == null or shared_vertex_key == StringName():
		return shell_quad_ids
	var unique_shell_quad_lookup: Dictionary = {}
	var owner_records_lookup: Dictionary = _resolve_shared_vertex_owner_records_lookup()
	for owner_record_variant in owner_records_lookup.get(shared_vertex_key, []):
		var owner_record: Dictionary = owner_record_variant
		var shell_quad_id: StringName = StringName(owner_record.get("shell_quad_id", StringName()))
		if shell_quad_id == StringName() or unique_shell_quad_lookup.has(shell_quad_id):
			continue
		unique_shell_quad_lookup[shell_quad_id] = true
		shell_quad_ids.append(String(shell_quad_id))
	return shell_quad_ids

func _ensure_shell_quad_patch_offset_storage(shell_quad_state: Resource, shell_patch_states: Array = []) -> void:
	if shell_quad_state == null:
		return
	var expected_patch_count: int = maxi(shell_quad_state.width_voxels, 1) * maxi(shell_quad_state.height_voxels, 1)
	var patch_offset_cells: PackedFloat32Array = PackedFloat32Array(shell_quad_state.patch_offset_cells)
	var needs_rebuild: bool = patch_offset_cells.size() != expected_patch_count
	if not needs_rebuild and not shell_patch_states.is_empty() and _packed_float_array_is_effectively_zero(patch_offset_cells):
		needs_rebuild = _shell_patch_states_have_non_zero_offset(shell_patch_states)
	if not needs_rebuild:
		return
	patch_offset_cells.resize(expected_patch_count)
	for offset_index: int in range(expected_patch_count):
		patch_offset_cells[offset_index] = 0.0
	for patch_state in shell_patch_states:
		if patch_state == null:
			continue
		var patch_grid_coords: Vector2i = _resolve_patch_grid_coords_from_patch_state(shell_quad_state, patch_state)
		var patch_offset_index: int = _resolve_shell_quad_patch_offset_index(
			shell_quad_state,
			patch_grid_coords.x,
			patch_grid_coords.y
		)
		if patch_offset_index < 0 or patch_offset_index >= patch_offset_cells.size():
			continue
		patch_offset_cells[patch_offset_index] = _resolve_patch_offset_without_shell_storage(patch_state)
	shell_quad_state.patch_offset_cells = patch_offset_cells

func _ensure_shell_quad_vertex_offset_storage(shell_quad_state: Resource, shell_patch_states: Array = []) -> void:
	if shell_quad_state == null:
		return
	_ensure_shell_quad_patch_offset_storage(shell_quad_state, shell_patch_states)
	var width_steps: int = maxi(shell_quad_state.width_voxels, 1)
	var height_steps: int = maxi(shell_quad_state.height_voxels, 1)
	var expected_vertex_count: int = (width_steps + 1) * (height_steps + 1)
	var vertex_offset_cells: PackedFloat32Array = PackedFloat32Array(shell_quad_state.vertex_offset_cells)
	var needs_rebuild: bool = vertex_offset_cells.size() != expected_vertex_count
	if not needs_rebuild and not shell_patch_states.is_empty() and _packed_float_array_is_effectively_zero(vertex_offset_cells):
		needs_rebuild = _shell_patch_states_have_non_zero_offset(shell_patch_states)
	if not needs_rebuild:
		return
	var patch_offset_lookup: Dictionary = _build_shell_patch_offset_lookup(shell_quad_state)
	vertex_offset_cells.resize(expected_vertex_count)
	for vertex_v_index: int in range(height_steps + 1):
		for vertex_u_index: int in range(width_steps + 1):
			var vertex_offset_index: int = _resolve_shell_quad_vertex_offset_index(
				shell_quad_state,
				vertex_u_index,
				vertex_v_index
			)
			if vertex_offset_index < 0 or vertex_offset_index >= vertex_offset_cells.size():
				continue
			vertex_offset_cells[vertex_offset_index] = _resolve_vertex_offset_average(
				patch_offset_lookup,
				vertex_u_index,
				vertex_v_index,
				width_steps,
				height_steps
			)
	shell_quad_state.vertex_offset_cells = vertex_offset_cells

func _packed_float_array_is_effectively_zero(values: PackedFloat32Array) -> bool:
	for value: float in values:
		if not is_zero_approx(value):
			return false
	return true

func _shell_patch_states_have_non_zero_offset(shell_patch_states: Array) -> bool:
	for patch_state in shell_patch_states:
		if patch_state == null:
			continue
		if not is_zero_approx(_resolve_patch_offset_without_shell_storage(patch_state)):
			return true
	return false

func _resolve_patch_grid_coords_from_patch_state(shell_quad_state: Resource, patch_state: Resource) -> Vector2i:
	if patch_state == null:
		return Vector2i.ZERO
	var width_steps: int = maxi(shell_quad_state.width_voxels, 1)
	var height_steps: int = maxi(shell_quad_state.height_voxels, 1)
	var grid_u_index: int = int(patch_state.get("grid_u_index"))
	var grid_v_index: int = int(patch_state.get("grid_v_index"))
	if grid_u_index >= 0 and grid_u_index < width_steps and grid_v_index >= 0 and grid_v_index < height_steps:
		return Vector2i(grid_u_index, grid_v_index)
	var edge_u_step: Vector3 = shell_quad_state.edge_u_local / float(width_steps)
	var edge_v_step: Vector3 = shell_quad_state.edge_v_local / float(height_steps)
	return _resolve_patch_grid_coords(shell_quad_state, patch_state, edge_u_step, edge_v_step)

func _resolve_shell_quad_patch_offset_index(shell_quad_state: Resource, u_index: int, v_index: int) -> int:
	if shell_quad_state == null:
		return -1
	var width_steps: int = maxi(shell_quad_state.width_voxels, 1)
	var height_steps: int = maxi(shell_quad_state.height_voxels, 1)
	if u_index < 0 or u_index >= width_steps or v_index < 0 or v_index >= height_steps:
		return -1
	return (v_index * width_steps) + u_index

func _resolve_shell_quad_vertex_offset_index(shell_quad_state: Resource, u_index: int, v_index: int) -> int:
	if shell_quad_state == null:
		return -1
	var width_steps: int = maxi(shell_quad_state.width_voxels, 1)
	var height_steps: int = maxi(shell_quad_state.height_voxels, 1)
	if u_index < 0 or u_index > width_steps or v_index < 0 or v_index > height_steps:
		return -1
	return (v_index * (width_steps + 1)) + u_index

func _resolve_shell_patch_offset_data_for_patch(patch_state: Resource) -> Dictionary:
	if patch_state == null or patch_state.shell_quad_id == StringName():
		return {}
	var shell_quad_state: Resource = get_current_shell_quad_state_by_id(patch_state.shell_quad_id)
	if shell_quad_state == null:
		return {}
	_ensure_shell_quad_patch_offset_storage(shell_quad_state)
	var patch_offset_index: int = _resolve_shell_quad_patch_offset_index(
		shell_quad_state,
		int(patch_state.get("grid_u_index")),
		int(patch_state.get("grid_v_index"))
	)
	if patch_offset_index < 0:
		return {}
	var patch_offset_cells: PackedFloat32Array = PackedFloat32Array(shell_quad_state.patch_offset_cells)
	if patch_offset_index >= patch_offset_cells.size():
		return {}
	return {
		"shell_quad_state": shell_quad_state,
		"index": patch_offset_index,
		"value": float(patch_offset_cells[patch_offset_index]),
	}

func _resolve_shell_vertex_offset_cells(
	shell_quad_state: Resource,
	u_index: int,
	v_index: int,
	fallback_patch_offset_lookup: Dictionary = {}
) -> float:
	if shell_quad_state == null:
		return 0.0
	_ensure_shell_quad_vertex_offset_storage(shell_quad_state)
	var vertex_offset_index: int = _resolve_shell_quad_vertex_offset_index(shell_quad_state, u_index, v_index)
	if vertex_offset_index < 0:
		return 0.0
	var vertex_offset_cells: PackedFloat32Array = PackedFloat32Array(shell_quad_state.vertex_offset_cells)
	if vertex_offset_index < vertex_offset_cells.size():
		return float(vertex_offset_cells[vertex_offset_index])
	var width_steps: int = maxi(shell_quad_state.width_voxels, 1)
	var height_steps: int = maxi(shell_quad_state.height_voxels, 1)
	return _resolve_vertex_offset_average(
		fallback_patch_offset_lookup,
		u_index,
		v_index,
		width_steps,
		height_steps
	)

func _resolve_shell_vertex_local(
	shell_quad_state: Resource,
	u_index: int,
	v_index: int,
	edge_u_step: Vector3,
	edge_v_step: Vector3,
	fallback_patch_offset_lookup: Dictionary = {}
) -> Vector3:
	if shell_quad_state == null:
		return Vector3.ZERO
	var shared_vertex_local: Variant = _resolve_shell_shared_vertex_current_local(
		shell_quad_state,
		u_index,
		v_index,
		edge_u_step,
		edge_v_step
	)
	if shared_vertex_local is Vector3:
		return shared_vertex_local
	return _resolve_shell_vertex_local_from_per_quad_offsets(
		shell_quad_state,
		u_index,
		v_index,
		edge_u_step,
		edge_v_step,
		fallback_patch_offset_lookup
	)

func _sync_shell_vertex_offsets_from_patch_storage(shell_quad_state: Resource) -> void:
	if shell_quad_state == null:
		return
	_ensure_shell_quad_patch_offset_storage(shell_quad_state)
	var width_steps: int = maxi(shell_quad_state.width_voxels, 1)
	var height_steps: int = maxi(shell_quad_state.height_voxels, 1)
	var patch_offset_lookup: Dictionary = _build_shell_patch_offset_lookup(shell_quad_state)
	var vertex_offset_cells: PackedFloat32Array = PackedFloat32Array(shell_quad_state.vertex_offset_cells)
	vertex_offset_cells.resize((width_steps + 1) * (height_steps + 1))
	for vertex_v_index: int in range(height_steps + 1):
		for vertex_u_index: int in range(width_steps + 1):
			var vertex_offset_index: int = _resolve_shell_quad_vertex_offset_index(
				shell_quad_state,
				vertex_u_index,
				vertex_v_index
			)
			if vertex_offset_index < 0 or vertex_offset_index >= vertex_offset_cells.size():
				continue
			vertex_offset_cells[vertex_offset_index] = _resolve_vertex_offset_average(
				patch_offset_lookup,
				vertex_u_index,
				vertex_v_index,
				width_steps,
				height_steps
			)
	shell_quad_state.vertex_offset_cells = vertex_offset_cells
	_sync_shared_vertex_positions_from_shell_quad(shell_quad_state)
	shell_quad_state.dirty = true
	if current_shell_mesh_state != null:
		current_shell_mesh_state.dirty = true

func _sync_shared_vertex_positions_from_shell_quad(shell_quad_state: Resource) -> void:
	if current_shell_mesh_state == null or shell_quad_state == null:
		return
	_ensure_shell_shared_vertex_storage()
	var width_steps: int = maxi(shell_quad_state.width_voxels, 1)
	var height_steps: int = maxi(shell_quad_state.height_voxels, 1)
	var edge_u_step: Vector3 = shell_quad_state.edge_u_local / float(width_steps)
	var edge_v_step: Vector3 = shell_quad_state.edge_v_local / float(height_steps)
	for vertex_v_index: int in range(height_steps + 1):
		for vertex_u_index: int in range(width_steps + 1):
			var next_vertex_local: Vector3 = _resolve_shell_vertex_local_from_per_quad_offsets(
				shell_quad_state,
				vertex_u_index,
				vertex_v_index,
				edge_u_step,
				edge_v_step
			)
			_set_shell_shared_vertex_current_local(
				shell_quad_state,
				vertex_u_index,
				vertex_v_index,
				next_vertex_local,
				edge_u_step,
				edge_v_step
			)

func _sync_shell_quad_vertex_offset_cells_from_shared_positions(shell_quad_state: Resource) -> void:
	if current_shell_mesh_state == null or shell_quad_state == null:
		return
	_ensure_shell_shared_vertex_storage()
	var width_steps: int = maxi(shell_quad_state.width_voxels, 1)
	var height_steps: int = maxi(shell_quad_state.height_voxels, 1)
	var edge_u_step: Vector3 = shell_quad_state.edge_u_local / float(width_steps)
	var edge_v_step: Vector3 = shell_quad_state.edge_v_local / float(height_steps)
	var shell_normal: Vector3 = shell_quad_state.normal.normalized()
	var vertex_offset_cells: PackedFloat32Array = PackedFloat32Array(shell_quad_state.vertex_offset_cells)
	vertex_offset_cells.resize((width_steps + 1) * (height_steps + 1))
	for vertex_v_index: int in range(height_steps + 1):
		for vertex_u_index: int in range(width_steps + 1):
			var vertex_offset_index: int = _resolve_shell_quad_vertex_offset_index(
				shell_quad_state,
				vertex_u_index,
				vertex_v_index
			)
			if vertex_offset_index < 0 or vertex_offset_index >= vertex_offset_cells.size():
				continue
			var baseline_vertex_local: Variant = _resolve_shell_shared_vertex_baseline_local(
				shell_quad_state,
				vertex_u_index,
				vertex_v_index,
				edge_u_step,
				edge_v_step
			)
			var current_vertex_local: Variant = _resolve_shell_shared_vertex_current_local(
				shell_quad_state,
				vertex_u_index,
				vertex_v_index,
				edge_u_step,
				edge_v_step
			)
			if baseline_vertex_local is not Vector3 or current_vertex_local is not Vector3:
				continue
			vertex_offset_cells[vertex_offset_index] = maxf(
				(Vector3(baseline_vertex_local) - Vector3(current_vertex_local)).dot(shell_normal),
				0.0
			)
	shell_quad_state.vertex_offset_cells = vertex_offset_cells
	shell_quad_state.dirty = true

func _sync_shell_patch_offsets_from_vertex_storage(shell_quad_state: Resource) -> void:
	if shell_quad_state == null:
		return
	_ensure_shell_quad_vertex_offset_storage(shell_quad_state)
	_ensure_shell_quad_patch_offset_storage(shell_quad_state)
	_sync_shell_quad_vertex_offset_cells_from_shared_positions(shell_quad_state)
	var width_steps: int = maxi(shell_quad_state.width_voxels, 1)
	var height_steps: int = maxi(shell_quad_state.height_voxels, 1)
	var patch_offset_cells: PackedFloat32Array = PackedFloat32Array(shell_quad_state.patch_offset_cells)
	var patch_states_by_shell_quad_id: Dictionary = _build_patch_states_by_shell_quad_id()
	var shell_patch_lookup: Dictionary = {}
	for patch_state: Resource in patch_states_by_shell_quad_id.get(shell_quad_state.shell_quad_id, []):
		if patch_state == null:
			continue
		var patch_grid_key: StringName = _build_shell_patch_grid_key(
			shell_quad_state.shell_quad_id,
			int(patch_state.get("grid_u_index")),
			int(patch_state.get("grid_v_index"))
		)
		shell_patch_lookup[patch_grid_key] = patch_state
	for patch_v_index: int in range(height_steps):
		for patch_u_index: int in range(width_steps):
			var patch_offset_index: int = _resolve_shell_quad_patch_offset_index(shell_quad_state, patch_u_index, patch_v_index)
			if patch_offset_index < 0 or patch_offset_index >= patch_offset_cells.size():
				continue
			var averaged_offset: float = (
				_resolve_shell_vertex_offset_cells(shell_quad_state, patch_u_index, patch_v_index)
				+ _resolve_shell_vertex_offset_cells(shell_quad_state, patch_u_index + 1, patch_v_index)
				+ _resolve_shell_vertex_offset_cells(shell_quad_state, patch_u_index, patch_v_index + 1)
				+ _resolve_shell_vertex_offset_cells(shell_quad_state, patch_u_index + 1, patch_v_index + 1)
			) / 4.0
			patch_offset_cells[patch_offset_index] = averaged_offset
			var patch_grid_key: StringName = _build_shell_patch_grid_key(
				shell_quad_state.shell_quad_id,
				patch_u_index,
				patch_v_index
			)
			var patch_state: Resource = shell_patch_lookup.get(patch_grid_key, null)
			if patch_state == null:
				continue
			patch_state.current_offset_cells = averaged_offset
			_sync_patch_current_quad_from_offset_cells(patch_state, averaged_offset)
			patch_state.dirty = true
	shell_quad_state.patch_offset_cells = patch_offset_cells
	shell_quad_state.dirty = true
	if current_shell_mesh_state != null:
		current_shell_mesh_state.dirty = true

func _resolve_patch_offset_without_shell_storage(patch_state: Resource) -> float:
	if patch_state == null:
		return 0.0
	var stored_offset_cells: float = float(patch_state.get("current_offset_cells"))
	if not is_zero_approx(stored_offset_cells):
		return stored_offset_cells
	return _resolve_geometry_offset_cells(patch_state)

func _resolve_shell_vertex_max_offset_cells(
	shell_quad_state: Resource,
	vertex_u_index: int,
	vertex_v_index: int,
	cell_size_meters: float
) -> float:
	if shell_quad_state == null:
		return 0.0
	var patch_state_lookup: Dictionary = _build_patch_state_lookup_by_shell_grid_key()
	var has_owner: bool = false
	var max_offset_cells: float = 0.0
	for patch_v_index: int in [vertex_v_index - 1, vertex_v_index]:
		for patch_u_index: int in [vertex_u_index - 1, vertex_u_index]:
			var patch_grid_key: StringName = _build_shell_patch_grid_key(
				shell_quad_state.shell_quad_id,
				patch_u_index,
				patch_v_index
			)
			var patch_state: Resource = patch_state_lookup.get(patch_grid_key, null)
			if patch_state == null:
				continue
			var patch_max_offset_cells: float = float(patch_state.max_inward_offset_meters) / maxf(cell_size_meters, 0.0001)
			if not has_owner:
				max_offset_cells = patch_max_offset_cells
				has_owner = true
				continue
			max_offset_cells = minf(max_offset_cells, patch_max_offset_cells)
	if not has_owner:
		return 0.0
	return maxf(max_offset_cells, 0.0)

func _resolve_patch_grid_coords(
	shell_quad_state: Resource,
	patch_state: Resource,
	edge_u_step: Vector3,
	edge_v_step: Vector3
) -> Vector2i:
	var delta: Vector3 = patch_state.baseline_quad.origin_local - shell_quad_state.origin_local
	var u_index: int = int(round(delta.dot(edge_u_step) / maxf(edge_u_step.length_squared(), 0.000001)))
	var v_index: int = int(round(delta.dot(edge_v_step) / maxf(edge_v_step.length_squared(), 0.000001)))
	return Vector2i(u_index, v_index)

func _resolve_patch_offset_local(patch_state: Resource) -> float:
	return resolve_current_offset_cells(patch_state)

func _build_shell_vertex_grid(
	shell_quad_state: Resource,
	patch_offset_lookup: Dictionary,
	_full_width_steps: int,
	_full_height_steps: int,
	start_u_index: int,
	start_v_index: int,
	localized_width_steps: int,
	localized_height_steps: int,
	edge_u_step: Vector3,
	edge_v_step: Vector3
) -> Array:
	var vertex_grid: Array = []
	_ensure_shell_quad_vertex_offset_storage(shell_quad_state)
	for v_index: int in range(localized_height_steps + 1):
		var row: Array = []
		for u_index: int in range(localized_width_steps + 1):
			var global_u_index: int = start_u_index + u_index
			var global_v_index: int = start_v_index + v_index
			row.append(
				_resolve_shell_vertex_local(
					shell_quad_state,
					global_u_index,
					global_v_index,
					edge_u_step,
					edge_v_step,
					patch_offset_lookup
				)
			)
		vertex_grid.append(row)
	return vertex_grid

func _resolve_localized_shell_patch_bounds(
	changed_patch_coord_lookup: Dictionary,
	full_width_steps: int,
	full_height_steps: int
) -> Dictionary:
	var min_u_index: int = full_width_steps - 1
	var max_u_index: int = 0
	var min_v_index: int = full_height_steps - 1
	var max_v_index: int = 0
	var has_changed_patch: bool = false
	for patch_grid_coords_variant in changed_patch_coord_lookup.keys():
		if patch_grid_coords_variant is not Vector2i:
			continue
		var patch_grid_coords: Vector2i = patch_grid_coords_variant
		if not has_changed_patch:
			min_u_index = patch_grid_coords.x
			max_u_index = patch_grid_coords.x
			min_v_index = patch_grid_coords.y
			max_v_index = patch_grid_coords.y
			has_changed_patch = true
			continue
		min_u_index = mini(min_u_index, patch_grid_coords.x)
		max_u_index = maxi(max_u_index, patch_grid_coords.x)
		min_v_index = mini(min_v_index, patch_grid_coords.y)
		max_v_index = maxi(max_v_index, patch_grid_coords.y)
	if not has_changed_patch:
		return {
			"start_u": 0,
			"start_v": 0,
			"end_u": full_width_steps,
			"end_v": full_height_steps,
			"width": full_width_steps,
			"height": full_height_steps,
		}
	var localized_start_u: int = maxi(min_u_index - 1, 0)
	var localized_end_u: int = mini(max_u_index + 2, full_width_steps)
	var localized_start_v: int = maxi(min_v_index - 1, 0)
	var localized_end_v: int = mini(max_v_index + 2, full_height_steps)
	return {
		"start_u": localized_start_u,
		"start_v": localized_start_v,
		"end_u": localized_end_u,
		"end_v": localized_end_v,
		"width": maxi(localized_end_u - localized_start_u, 1),
		"height": maxi(localized_end_v - localized_start_v, 1),
	}

func _append_shell_outer_strip_quads(
	merged_geometry,
	shell_quad_state: Resource,
	localized_bounds: Dictionary,
	full_width_steps: int,
	full_height_steps: int,
	edge_u_step: Vector3,
	edge_v_step: Vector3
) -> void:
	var start_u: int = int(localized_bounds.get("start_u", 0))
	var start_v: int = int(localized_bounds.get("start_v", 0))
	var end_u: int = int(localized_bounds.get("end_u", full_width_steps))
	var end_v: int = int(localized_bounds.get("end_v", full_height_steps))
	if start_v > 0:
		_append_baseline_shell_subquad(
			merged_geometry,
			shell_quad_state,
			0,
			0,
			full_width_steps,
			start_v,
			edge_u_step,
			edge_v_step
		)
	if end_v < full_height_steps:
		_append_baseline_shell_subquad(
			merged_geometry,
			shell_quad_state,
			0,
			end_v,
			full_width_steps,
			full_height_steps - end_v,
			edge_u_step,
			edge_v_step
		)
	var localized_height: int = maxi(end_v - start_v, 0)
	if start_u > 0 and localized_height > 0:
		_append_baseline_shell_subquad(
			merged_geometry,
			shell_quad_state,
			0,
			start_v,
			start_u,
			localized_height,
			edge_u_step,
			edge_v_step
		)
	if end_u < full_width_steps and localized_height > 0:
		_append_baseline_shell_subquad(
			merged_geometry,
			shell_quad_state,
			end_u,
			start_v,
			full_width_steps - end_u,
			localized_height,
			edge_u_step,
			edge_v_step
		)

func _append_baseline_shell_subquad(
	merged_geometry,
	shell_quad_state: Resource,
	start_u: int,
	start_v: int,
	width_steps: int,
	height_steps: int,
	edge_u_step: Vector3,
	edge_v_step: Vector3
) -> void:
	if merged_geometry == null or shell_quad_state == null or width_steps <= 0 or height_steps <= 0:
		return
	var surface_quad = CraftedItemCanonicalSurfaceQuadScript.new()
	surface_quad.origin_local = (
		shell_quad_state.origin_local
		+ (edge_u_step * float(start_u))
		+ (edge_v_step * float(start_v))
	)
	surface_quad.edge_u_local = edge_u_step * float(width_steps)
	surface_quad.edge_v_local = edge_v_step * float(height_steps)
	surface_quad.normal = shell_quad_state.normal
	surface_quad.material_variant_id = shell_quad_state.material_variant_id
	surface_quad.width_voxels = width_steps
	surface_quad.height_voxels = height_steps
	merged_geometry.surface_quads.append(surface_quad)

func _build_localized_shell_quad_state(
	shell_quad_state: Resource,
	localized_bounds: Dictionary,
	edge_u_step: Vector3,
	edge_v_step: Vector3
) -> Resource:
	var localized_shell_quad_state = shell_quad_state.duplicate(true)
	var localized_start_u: int = int(localized_bounds.get("start_u", 0))
	var localized_start_v: int = int(localized_bounds.get("start_v", 0))
	var localized_width: int = int(localized_bounds.get("width", shell_quad_state.width_voxels))
	var localized_height: int = int(localized_bounds.get("height", shell_quad_state.height_voxels))
	localized_shell_quad_state.origin_local = (
		shell_quad_state.origin_local
		+ (edge_u_step * float(localized_start_u))
		+ (edge_v_step * float(localized_start_v))
	)
	localized_shell_quad_state.edge_u_local = edge_u_step * float(localized_width)
	localized_shell_quad_state.edge_v_local = edge_v_step * float(localized_height)
	localized_shell_quad_state.width_voxels = localized_width
	localized_shell_quad_state.height_voxels = localized_height
	return localized_shell_quad_state

func _resolve_vertex_offset_average(
	patch_offset_lookup: Dictionary,
	u_index: int,
	v_index: int,
	width_steps: int,
	height_steps: int
) -> float:
	var offset_sum: float = 0.0
	var sample_count: int = 0
	for patch_v_index: int in [v_index - 1, v_index]:
		if patch_v_index < 0 or patch_v_index >= height_steps:
			continue
		for patch_u_index: int in [u_index - 1, u_index]:
			if patch_u_index < 0 or patch_u_index >= width_steps:
				continue
			var patch_offset: Variant = patch_offset_lookup.get(Vector2i(patch_u_index, patch_v_index), null)
			if patch_offset is float:
				offset_sum += patch_offset
				sample_count += 1
	if sample_count <= 0:
		return 0.0
	return offset_sum / float(sample_count)

func _append_shell_surface_triangles(
	merged_geometry,
	shell_quad_state: Resource,
	vertex_grid: Array,
	vertex_normal_grid: Array,
	width_steps: int,
	height_steps: int,
	_patch_offset_lookup: Dictionary,
	_full_width_steps: int,
	_full_height_steps: int,
	_start_u_index: int,
	_start_v_index: int,
	_edge_u_step: Vector3,
	_edge_v_step: Vector3,
	material_variant_id: StringName,
	expected_normal: Vector3,
	force_dense_surface: bool = false
) -> void:
	var consumed_cells: Array = _build_shell_cell_consumed_grid(width_steps, height_steps)
	for v_index: int in range(height_steps):
		for u_index: int in range(width_steps):
			if consumed_cells[v_index][u_index]:
				continue
			var vertex_a: Vector3 = vertex_grid[v_index][u_index]
			var vertex_b: Vector3 = vertex_grid[v_index + 1][u_index]
			var vertex_c: Vector3 = vertex_grid[v_index + 1][u_index + 1]
			var vertex_d: Vector3 = vertex_grid[v_index][u_index + 1]
			if not force_dense_surface:
				if _try_append_merged_planar_shell_quad_region(
					merged_geometry,
					vertex_grid,
					width_steps,
					height_steps,
					consumed_cells,
					u_index,
					v_index,
					material_variant_id,
					expected_normal
				):
					continue
			consumed_cells[v_index][u_index] = true
			if _try_append_center_subdivided_shell_cell(
				merged_geometry,
				shell_quad_state,
				vertex_a,
				vertex_b,
				vertex_c,
				vertex_d,
				_resolve_shell_cell_edge_midpoint_vertex_from_vertices(vertex_a, vertex_b),
				_resolve_shell_cell_edge_midpoint_vertex_from_vertices(vertex_b, vertex_c),
				_resolve_shell_cell_edge_midpoint_vertex_from_vertices(vertex_c, vertex_d),
				_resolve_shell_cell_edge_midpoint_vertex_from_vertices(vertex_d, vertex_a),
				_resolve_shell_cell_center_vertex_from_vertices(vertex_a, vertex_b, vertex_c, vertex_d),
				vertex_normal_grid[v_index][u_index],
				vertex_normal_grid[v_index + 1][u_index],
				vertex_normal_grid[v_index + 1][u_index + 1],
				vertex_normal_grid[v_index][u_index + 1],
				material_variant_id,
				expected_normal
			):
				continue
			_append_best_shell_cell_triangles(
				merged_geometry,
				vertex_a,
				vertex_b,
				vertex_c,
				vertex_d,
				vertex_normal_grid[v_index][u_index],
				vertex_normal_grid[v_index + 1][u_index],
				vertex_normal_grid[v_index + 1][u_index + 1],
				vertex_normal_grid[v_index][u_index + 1],
				material_variant_id,
				expected_normal
			)

func _build_shell_cell_consumed_grid(width_steps: int, height_steps: int) -> Array:
	var consumed_cells: Array = []
	for v_index: int in range(height_steps):
		var row: Array = []
		row.resize(width_steps)
		row.fill(false)
		consumed_cells.append(row)
	return consumed_cells

func _try_append_merged_planar_shell_quad_region(
	merged_geometry,
	vertex_grid: Array,
	width_steps: int,
	height_steps: int,
	consumed_cells: Array,
	start_u_index: int,
	start_v_index: int,
	material_variant_id: StringName,
	expected_normal: Vector3
) -> bool:
	var planar_cell_info: Dictionary = _resolve_planar_shell_cell_info(
		vertex_grid,
		start_u_index,
		start_v_index,
		expected_normal
	)
	if planar_cell_info.is_empty():
		return false
	var plane_normal: Vector3 = planar_cell_info.get("plane_normal", Vector3.ZERO)
	var plane_distance: float = float(planar_cell_info.get("plane_distance", 0.0))
	var region_width: int = 1
	while start_u_index + region_width < width_steps:
		if consumed_cells[start_v_index][start_u_index + region_width]:
			break
		if not _cell_matches_planar_region(
			vertex_grid,
			start_u_index + region_width,
			start_v_index,
			expected_normal,
			plane_normal,
			plane_distance
		):
			break
		region_width += 1
	var region_height: int = 1
	while start_v_index + region_height < height_steps:
		var can_extend_row: bool = true
		for region_u_offset: int in range(region_width):
			var test_u_index: int = start_u_index + region_u_offset
			var test_v_index: int = start_v_index + region_height
			if consumed_cells[test_v_index][test_u_index]:
				can_extend_row = false
				break
			if not _cell_matches_planar_region(
				vertex_grid,
				test_u_index,
				test_v_index,
				expected_normal,
				plane_normal,
				plane_distance
			):
				can_extend_row = false
				break
		if not can_extend_row:
			break
		region_height += 1
	for region_v_offset: int in range(region_height):
		for region_u_offset: int in range(region_width):
			consumed_cells[start_v_index + region_v_offset][start_u_index + region_u_offset] = true
	var vertex_a: Vector3 = vertex_grid[start_v_index][start_u_index]
	var vertex_b: Vector3 = vertex_grid[start_v_index + region_height][start_u_index]
	var vertex_d: Vector3 = vertex_grid[start_v_index][start_u_index + region_width]
	var surface_quad = CraftedItemCanonicalSurfaceQuadScript.new()
	surface_quad.origin_local = vertex_a
	surface_quad.edge_u_local = vertex_d - vertex_a
	surface_quad.edge_v_local = vertex_b - vertex_a
	surface_quad.normal = plane_normal
	surface_quad.material_variant_id = material_variant_id
	surface_quad.width_voxels = region_width
	surface_quad.height_voxels = region_height
	merged_geometry.surface_quads.append(surface_quad)
	return true

func _resolve_planar_shell_cell_info(
	vertex_grid: Array,
	u_index: int,
	v_index: int,
	expected_normal: Vector3
) -> Dictionary:
	var vertex_a: Vector3 = vertex_grid[v_index][u_index]
	var vertex_b: Vector3 = vertex_grid[v_index + 1][u_index]
	var vertex_c: Vector3 = vertex_grid[v_index + 1][u_index + 1]
	var vertex_d: Vector3 = vertex_grid[v_index][u_index + 1]
	var edge_ab: Vector3 = vertex_b - vertex_a
	var edge_ad: Vector3 = vertex_d - vertex_a
	if edge_ab.is_zero_approx() or edge_ad.is_zero_approx():
		return {}
	var resolved_normal: Vector3 = edge_ab.cross(edge_ad).normalized()
	if resolved_normal == Vector3.ZERO:
		return {}
	var target_normal: Vector3 = expected_normal.normalized() if expected_normal != Vector3.ZERO else resolved_normal
	if resolved_normal.dot(target_normal) < 0.0:
		resolved_normal = -resolved_normal
	if not _is_cell_planar(vertex_a, vertex_b, vertex_c, vertex_d, resolved_normal):
		return {}
	return {
		"plane_normal": resolved_normal,
		"plane_distance": resolved_normal.dot(vertex_a),
	}

func _cell_matches_planar_region(
	vertex_grid: Array,
	u_index: int,
	v_index: int,
	expected_normal: Vector3,
	plane_normal: Vector3,
	plane_distance: float
) -> bool:
	var planar_cell_info: Dictionary = _resolve_planar_shell_cell_info(
		vertex_grid,
		u_index,
		v_index,
		expected_normal
	)
	if planar_cell_info.is_empty():
		return false
	var cell_plane_normal: Vector3 = planar_cell_info.get("plane_normal", Vector3.ZERO)
	if cell_plane_normal == Vector3.ZERO:
		return false
	if cell_plane_normal.dot(plane_normal) < 0.9999:
		return false
	return is_equal_approx(float(planar_cell_info.get("plane_distance", 0.0)), plane_distance)

func _try_append_center_subdivided_shell_cell(
	merged_geometry,
	shell_quad_state: Resource,
	vertex_a: Vector3,
	vertex_b: Vector3,
	vertex_c: Vector3,
	vertex_d: Vector3,
	edge_midpoint_ab: Vector3,
	edge_midpoint_bc: Vector3,
	edge_midpoint_cd: Vector3,
	edge_midpoint_da: Vector3,
	center_vertex: Vector3,
	vertex_a_normal: Vector3,
	vertex_b_normal: Vector3,
	vertex_c_normal: Vector3,
	vertex_d_normal: Vector3,
	material_variant_id: StringName,
	expected_normal: Vector3
) -> bool:
	if not _should_subdivide_shell_cell(
		vertex_a,
		vertex_b,
		vertex_c,
		vertex_d,
		vertex_a_normal,
		vertex_b_normal,
		vertex_c_normal,
		vertex_d_normal,
		expected_normal
	):
		return false
	if shell_quad_state == null:
		edge_midpoint_ab = (vertex_a + vertex_b) * 0.5
		edge_midpoint_bc = (vertex_b + vertex_c) * 0.5
		edge_midpoint_cd = (vertex_c + vertex_d) * 0.5
		edge_midpoint_da = (vertex_d + vertex_a) * 0.5
		center_vertex = (vertex_a + vertex_b + vertex_c + vertex_d) * 0.25
	var center_normal: Vector3 = _resolve_center_vertex_normal(
		vertex_a_normal,
		vertex_b_normal,
		vertex_c_normal,
		vertex_d_normal,
		expected_normal
	)
	var edge_midpoint_ab_normal: Vector3 = _resolve_edge_midpoint_normal(vertex_a_normal, vertex_b_normal, center_normal, expected_normal)
	var edge_midpoint_bc_normal: Vector3 = _resolve_edge_midpoint_normal(vertex_b_normal, vertex_c_normal, center_normal, expected_normal)
	var edge_midpoint_cd_normal: Vector3 = _resolve_edge_midpoint_normal(vertex_c_normal, vertex_d_normal, center_normal, expected_normal)
	var edge_midpoint_da_normal: Vector3 = _resolve_edge_midpoint_normal(vertex_d_normal, vertex_a_normal, center_normal, expected_normal)
	_append_surface_triangle(
		merged_geometry,
		vertex_a,
		edge_midpoint_ab,
		center_vertex,
		material_variant_id,
		expected_normal,
		vertex_a_normal,
		edge_midpoint_ab_normal,
		center_normal
	)
	_append_surface_triangle(
		merged_geometry,
		edge_midpoint_ab,
		vertex_b,
		center_vertex,
		material_variant_id,
		expected_normal,
		edge_midpoint_ab_normal,
		vertex_b_normal,
		center_normal
	)
	_append_surface_triangle(
		merged_geometry,
		vertex_b,
		edge_midpoint_bc,
		center_vertex,
		material_variant_id,
		expected_normal,
		vertex_b_normal,
		edge_midpoint_bc_normal,
		center_normal
	)
	_append_surface_triangle(
		merged_geometry,
		edge_midpoint_bc,
		vertex_c,
		center_vertex,
		material_variant_id,
		expected_normal,
		edge_midpoint_bc_normal,
		vertex_c_normal,
		center_normal
	)
	_append_surface_triangle(
		merged_geometry,
		vertex_c,
		edge_midpoint_cd,
		center_vertex,
		material_variant_id,
		expected_normal,
		vertex_c_normal,
		edge_midpoint_cd_normal,
		center_normal
	)
	_append_surface_triangle(
		merged_geometry,
		edge_midpoint_cd,
		vertex_d,
		center_vertex,
		material_variant_id,
		expected_normal,
		edge_midpoint_cd_normal,
		vertex_d_normal,
		center_normal
	)
	_append_surface_triangle(
		merged_geometry,
		vertex_d,
		edge_midpoint_da,
		center_vertex,
		material_variant_id,
		expected_normal,
		vertex_d_normal,
		edge_midpoint_da_normal,
		center_normal
	)
	_append_surface_triangle(
		merged_geometry,
		edge_midpoint_da,
		vertex_a,
		center_vertex,
		material_variant_id,
		expected_normal,
		edge_midpoint_da_normal,
		vertex_a_normal,
		center_normal
	)
	return true

func _should_subdivide_shell_cell(
	vertex_a: Vector3,
	vertex_b: Vector3,
	vertex_c: Vector3,
	vertex_d: Vector3,
	vertex_a_normal: Vector3,
	vertex_b_normal: Vector3,
	vertex_c_normal: Vector3,
	vertex_d_normal: Vector3,
	expected_normal: Vector3
) -> bool:
	var best_diagonal_variant: int = _resolve_best_shell_cell_diagonal_variant(
		vertex_a,
		vertex_b,
		vertex_c,
		vertex_d,
		vertex_a_normal,
		vertex_b_normal,
		vertex_c_normal,
		vertex_d_normal,
		expected_normal
	)
	if best_diagonal_variant == 1:
		return true
	var best_triangle_normal_dot: float = _resolve_shell_cell_best_triangle_normal_dot(
		vertex_a,
		vertex_b,
		vertex_c,
		vertex_d,
		expected_normal,
		best_diagonal_variant
	)
	return best_triangle_normal_dot < 0.9995

func _resolve_center_vertex_normal(
	vertex_a_normal: Vector3,
	vertex_b_normal: Vector3,
	vertex_c_normal: Vector3,
	vertex_d_normal: Vector3,
	expected_normal: Vector3
) -> Vector3:
	var center_normal: Vector3 = Vector3.ZERO
	for vertex_normal: Vector3 in [vertex_a_normal, vertex_b_normal, vertex_c_normal, vertex_d_normal]:
		if vertex_normal == Vector3.ZERO:
			continue
		center_normal += vertex_normal.normalized()
	if center_normal == Vector3.ZERO:
		return expected_normal.normalized() if expected_normal != Vector3.ZERO else Vector3.UP
	return center_normal.normalized()

func _resolve_edge_midpoint_normal(
	vertex_normal_a: Vector3,
	vertex_normal_b: Vector3,
	center_normal: Vector3,
	expected_normal: Vector3
) -> Vector3:
	var midpoint_normal: Vector3 = Vector3.ZERO
	for vertex_normal: Vector3 in [vertex_normal_a, vertex_normal_b, center_normal]:
		if vertex_normal == Vector3.ZERO:
			continue
		midpoint_normal += vertex_normal.normalized()
	if midpoint_normal == Vector3.ZERO:
		return expected_normal.normalized() if expected_normal != Vector3.ZERO else Vector3.UP
	return midpoint_normal.normalized()

func _resolve_shell_cell_center_vertex_from_vertices(
	vertex_a: Vector3,
	vertex_b: Vector3,
	vertex_c: Vector3,
	vertex_d: Vector3
) -> Vector3:
	return (vertex_a + vertex_b + vertex_c + vertex_d) * 0.25

func _resolve_shell_cell_edge_midpoint_vertex_from_vertices(
	vertex_a: Vector3,
	vertex_b: Vector3
) -> Vector3:
	return (vertex_a + vertex_b) * 0.5

func _resolve_shell_cell_center_vertex(
	shell_quad_state: Resource,
	patch_offset_lookup: Dictionary,
	full_width_steps: int,
	full_height_steps: int,
	local_u_index: int,
	local_v_index: int,
	global_u_index: int,
	global_v_index: int,
	edge_u_step: Vector3,
	edge_v_step: Vector3,
	expected_normal: Vector3
) -> Vector3:
	if shell_quad_state == null:
		return Vector3.ZERO
	var baseline_center: Vector3 = (
		shell_quad_state.origin_local
		+ (edge_u_step * (float(local_u_index) + 0.5))
		+ (edge_v_step * (float(local_v_index) + 0.5))
	)
	var resolved_offset: float = 0.0
	var center_offset: Variant = patch_offset_lookup.get(Vector2i(global_u_index, global_v_index), null)
	if center_offset is float:
		resolved_offset = center_offset
	else:
		resolved_offset = _resolve_vertex_offset_average(
			patch_offset_lookup,
			global_u_index,
			global_v_index,
			full_width_steps,
			full_height_steps
		)
	var shell_normal: Vector3 = expected_normal.normalized() if expected_normal != Vector3.ZERO else shell_quad_state.normal.normalized()
	if shell_normal == Vector3.ZERO:
		return baseline_center
	return baseline_center - (shell_normal * resolved_offset)

func _resolve_shell_cell_edge_midpoint_vertex(
	shell_quad_state: Resource,
	patch_offset_lookup: Dictionary,
	global_u_index: int,
	global_v_index: int,
	local_u_index: int,
	local_v_index: int,
	edge_u_step: Vector3,
	edge_v_step: Vector3,
	expected_normal: Vector3,
	edge_id: StringName
) -> Vector3:
	if shell_quad_state == null:
		return Vector3.ZERO
	var baseline_midpoint: Vector3 = shell_quad_state.origin_local
	var resolved_offset: float = 0.0
	match edge_id:
		&"ab":
			baseline_midpoint += (edge_u_step * float(local_u_index)) + (edge_v_step * (float(local_v_index) + 0.5))
			resolved_offset = _resolve_edge_midpoint_offset(
				patch_offset_lookup,
				Vector2i(global_u_index, global_v_index),
				Vector2i(global_u_index - 1, global_v_index)
			)
		&"bc":
			baseline_midpoint += (edge_u_step * (float(local_u_index) + 0.5)) + (edge_v_step * float(local_v_index + 1))
			resolved_offset = _resolve_edge_midpoint_offset(
				patch_offset_lookup,
				Vector2i(global_u_index, global_v_index),
				Vector2i(global_u_index, global_v_index + 1)
			)
		&"cd":
			baseline_midpoint += (edge_u_step * float(local_u_index + 1)) + (edge_v_step * (float(local_v_index) + 0.5))
			resolved_offset = _resolve_edge_midpoint_offset(
				patch_offset_lookup,
				Vector2i(global_u_index, global_v_index),
				Vector2i(global_u_index + 1, global_v_index)
			)
		_:
			baseline_midpoint += (edge_u_step * (float(local_u_index) + 0.5)) + (edge_v_step * float(local_v_index))
			resolved_offset = _resolve_edge_midpoint_offset(
				patch_offset_lookup,
				Vector2i(global_u_index, global_v_index),
				Vector2i(global_u_index, global_v_index - 1)
			)
	var shell_normal: Vector3 = expected_normal.normalized() if expected_normal != Vector3.ZERO else shell_quad_state.normal.normalized()
	if shell_normal == Vector3.ZERO:
		return baseline_midpoint
	return baseline_midpoint - (shell_normal * resolved_offset)

func _resolve_edge_midpoint_offset(
	patch_offset_lookup: Dictionary,
	primary_patch_coords: Vector2i,
	secondary_patch_coords: Vector2i
) -> float:
	var offset_sum: float = 0.0
	var sample_count: int = 0
	for patch_coords: Vector2i in [primary_patch_coords, secondary_patch_coords]:
		var patch_offset: Variant = patch_offset_lookup.get(patch_coords, null)
		if patch_offset is float:
			offset_sum += patch_offset
			sample_count += 1
	if sample_count <= 0:
		return 0.0
	return offset_sum / float(sample_count)

func _is_cell_planar(
	vertex_a: Vector3,
	vertex_b: Vector3,
	vertex_c: Vector3,
	vertex_d: Vector3,
	plane_normal: Vector3
) -> bool:
	if plane_normal == Vector3.ZERO:
		return false
	var plane_distance: float = plane_normal.dot(vertex_a)
	return (
		is_equal_approx(plane_normal.dot(vertex_b), plane_distance)
		and is_equal_approx(plane_normal.dot(vertex_c), plane_distance)
		and is_equal_approx(plane_normal.dot(vertex_d), plane_distance)
	)

func _append_best_shell_cell_triangles(
	merged_geometry,
	vertex_a: Vector3,
	vertex_b: Vector3,
	vertex_c: Vector3,
	vertex_d: Vector3,
	vertex_a_normal: Vector3,
	vertex_b_normal: Vector3,
	vertex_c_normal: Vector3,
	vertex_d_normal: Vector3,
	material_variant_id: StringName,
	expected_normal: Vector3
) -> void:
	var diagonal_variant: int = _resolve_best_shell_cell_diagonal_variant(
		vertex_a,
		vertex_b,
		vertex_c,
		vertex_d,
		vertex_a_normal,
		vertex_b_normal,
		vertex_c_normal,
		vertex_d_normal,
		expected_normal
	)
	if diagonal_variant == 1:
		_append_surface_triangle(
			merged_geometry,
			vertex_a,
			vertex_b,
			vertex_d,
			material_variant_id,
			expected_normal,
			vertex_a_normal,
			vertex_b_normal,
			vertex_d_normal
		)
		_append_surface_triangle(
			merged_geometry,
			vertex_b,
			vertex_c,
			vertex_d,
			material_variant_id,
			expected_normal,
			vertex_b_normal,
			vertex_c_normal,
			vertex_d_normal
		)
		return
	_append_surface_triangle(
		merged_geometry,
		vertex_a,
		vertex_b,
		vertex_c,
		material_variant_id,
		expected_normal,
		vertex_a_normal,
		vertex_b_normal,
		vertex_c_normal
	)
	_append_surface_triangle(
		merged_geometry,
		vertex_a,
		vertex_c,
		vertex_d,
		material_variant_id,
		expected_normal,
		vertex_a_normal,
		vertex_c_normal,
		vertex_d_normal
	)

func _resolve_best_shell_cell_diagonal_variant(
	vertex_a: Vector3,
	vertex_b: Vector3,
	vertex_c: Vector3,
	vertex_d: Vector3,
	vertex_a_normal: Vector3,
	vertex_b_normal: Vector3,
	vertex_c_normal: Vector3,
	vertex_d_normal: Vector3,
	expected_normal: Vector3
) -> int:
	var primary_score: float = _score_shell_cell_diagonal_variant(
		vertex_a,
		vertex_b,
		vertex_c,
		vertex_a_normal,
		vertex_b_normal,
		vertex_c_normal,
		vertex_a,
		vertex_c,
		vertex_d,
		vertex_a_normal,
		vertex_c_normal,
		vertex_d_normal,
		expected_normal
	)
	var secondary_score: float = _score_shell_cell_diagonal_variant(
		vertex_a,
		vertex_b,
		vertex_d,
		vertex_a_normal,
		vertex_b_normal,
		vertex_d_normal,
		vertex_b,
		vertex_c,
		vertex_d,
		vertex_b_normal,
		vertex_c_normal,
		vertex_d_normal,
		expected_normal
	)
	return 1 if secondary_score > primary_score else 0

func _score_shell_cell_diagonal_variant(
	triangle_a_vertex_a: Vector3,
	triangle_a_vertex_b: Vector3,
	triangle_a_vertex_c: Vector3,
	triangle_a_normal_a: Vector3,
	triangle_a_normal_b: Vector3,
	triangle_a_normal_c: Vector3,
	triangle_b_vertex_a: Vector3,
	triangle_b_vertex_b: Vector3,
	triangle_b_vertex_c: Vector3,
	triangle_b_normal_a: Vector3,
	triangle_b_normal_b: Vector3,
	triangle_b_normal_c: Vector3,
	expected_normal: Vector3
) -> float:
	var triangle_a_face_normal: Vector3 = _resolve_oriented_triangle_normal(
		triangle_a_vertex_a,
		triangle_a_vertex_b,
		triangle_a_vertex_c,
		expected_normal
	)
	var triangle_b_face_normal: Vector3 = _resolve_oriented_triangle_normal(
		triangle_b_vertex_a,
		triangle_b_vertex_b,
		triangle_b_vertex_c,
		expected_normal
	)
	if triangle_a_face_normal == Vector3.ZERO or triangle_b_face_normal == Vector3.ZERO:
		return -INF
	return (
		_score_triangle_normal_alignment(
			triangle_a_face_normal,
			expected_normal,
			triangle_a_normal_a,
			triangle_a_normal_b,
			triangle_a_normal_c
		)
		+ _score_triangle_normal_alignment(
			triangle_b_face_normal,
			expected_normal,
			triangle_b_normal_a,
			triangle_b_normal_b,
			triangle_b_normal_c
		)
		+ triangle_a_face_normal.dot(triangle_b_face_normal)
	)

func _resolve_oriented_triangle_normal(
	vertex_a: Vector3,
	vertex_b: Vector3,
	vertex_c: Vector3,
	expected_normal: Vector3
) -> Vector3:
	var edge_ab: Vector3 = vertex_b - vertex_a
	var edge_ac: Vector3 = vertex_c - vertex_a
	if edge_ab.is_zero_approx() or edge_ac.is_zero_approx():
		return Vector3.ZERO
	var resolved_normal: Vector3 = edge_ab.cross(edge_ac).normalized()
	if resolved_normal == Vector3.ZERO:
		return Vector3.ZERO
	if expected_normal != Vector3.ZERO:
		var target_normal: Vector3 = expected_normal.normalized()
		if resolved_normal.dot(target_normal) < 0.0:
			resolved_normal = -resolved_normal
	return resolved_normal

func _score_triangle_normal_alignment(
	triangle_face_normal: Vector3,
	expected_normal: Vector3,
	vertex_normal_a: Vector3,
	vertex_normal_b: Vector3,
	vertex_normal_c: Vector3
) -> float:
	var score: float = 0.0
	if expected_normal != Vector3.ZERO:
		score += triangle_face_normal.dot(expected_normal.normalized())
	for vertex_normal: Vector3 in [vertex_normal_a, vertex_normal_b, vertex_normal_c]:
		if vertex_normal == Vector3.ZERO:
			continue
		score += triangle_face_normal.dot(vertex_normal.normalized())
	return score

func _resolve_shell_cell_best_triangle_normal_dot(
	vertex_a: Vector3,
	vertex_b: Vector3,
	vertex_c: Vector3,
	vertex_d: Vector3,
	expected_normal: Vector3,
	diagonal_variant: int
) -> float:
	if diagonal_variant == 1:
		var triangle_normal_variant_a: Vector3 = _resolve_oriented_triangle_normal(
			vertex_a,
			vertex_b,
			vertex_d,
			expected_normal
		)
		var triangle_normal_variant_b: Vector3 = _resolve_oriented_triangle_normal(
			vertex_b,
			vertex_c,
			vertex_d,
			expected_normal
		)
		if triangle_normal_variant_a == Vector3.ZERO or triangle_normal_variant_b == Vector3.ZERO:
			return -1.0
		return triangle_normal_variant_a.dot(triangle_normal_variant_b)
	var triangle_normal_a: Vector3 = _resolve_oriented_triangle_normal(
		vertex_a,
		vertex_b,
		vertex_c,
		expected_normal
	)
	var triangle_normal_b: Vector3 = _resolve_oriented_triangle_normal(
		vertex_a,
		vertex_c,
		vertex_d,
		expected_normal
	)
	if triangle_normal_a == Vector3.ZERO or triangle_normal_b == Vector3.ZERO:
		return -1.0
	return triangle_normal_a.dot(triangle_normal_b)

func _count_secondary_diagonal_cells_for_shell_quad(shell_quad_state: Resource, shell_patch_states: Array) -> int:
	if shell_quad_state == null or shell_patch_states.is_empty():
		return 0
	var full_width_steps: int = maxi(shell_quad_state.width_voxels, 1)
	var full_height_steps: int = maxi(shell_quad_state.height_voxels, 1)
	var edge_u_step: Vector3 = shell_quad_state.edge_u_local / float(full_width_steps)
	var edge_v_step: Vector3 = shell_quad_state.edge_v_local / float(full_height_steps)
	_ensure_shell_quad_patch_offset_storage(shell_quad_state, shell_patch_states)
	var patch_offset_lookup: Dictionary = _build_shell_patch_offset_lookup(shell_quad_state)
	var changed_patch_coord_lookup: Dictionary = _build_changed_patch_coord_lookup(shell_quad_state)
	var localized_bounds: Dictionary = _resolve_localized_shell_patch_bounds(
		changed_patch_coord_lookup,
		full_width_steps,
		full_height_steps
	)
	var localized_shell_quad_state: Resource = _build_localized_shell_quad_state(
		shell_quad_state,
		localized_bounds,
		edge_u_step,
		edge_v_step
	)
	var localized_width_steps: int = int(localized_bounds.get("width", 0))
	var localized_height_steps: int = int(localized_bounds.get("height", 0))
	var vertex_grid: Array = _build_shell_vertex_grid(
		shell_quad_state,
		patch_offset_lookup,
		full_width_steps,
		full_height_steps,
		int(localized_bounds.get("start_u", 0)),
		int(localized_bounds.get("start_v", 0)),
		localized_width_steps,
		localized_height_steps,
		edge_u_step,
		edge_v_step
	)
	var vertex_normal_grid: Array = _build_shell_vertex_normal_grid(
		vertex_grid,
		localized_width_steps,
		localized_height_steps,
		localized_shell_quad_state.normal
	)
	var secondary_diagonal_count: int = 0
	for v_index: int in range(localized_height_steps):
		for u_index: int in range(localized_width_steps):
			var vertex_a: Vector3 = vertex_grid[v_index][u_index]
			var vertex_b: Vector3 = vertex_grid[v_index + 1][u_index]
			var vertex_c: Vector3 = vertex_grid[v_index + 1][u_index + 1]
			var vertex_d: Vector3 = vertex_grid[v_index][u_index + 1]
			var resolved_normal: Vector3 = localized_shell_quad_state.normal.normalized()
			if resolved_normal == Vector3.ZERO:
				resolved_normal = (vertex_b - vertex_a).cross(vertex_d - vertex_a).normalized()
			if _is_cell_planar(vertex_a, vertex_b, vertex_c, vertex_d, resolved_normal):
				continue
			if _resolve_best_shell_cell_diagonal_variant(
				vertex_a,
				vertex_b,
				vertex_c,
				vertex_d,
				vertex_normal_grid[v_index][u_index],
				vertex_normal_grid[v_index + 1][u_index],
				vertex_normal_grid[v_index + 1][u_index + 1],
				vertex_normal_grid[v_index][u_index + 1],
				localized_shell_quad_state.normal
			) == 1:
				secondary_diagonal_count += 1
	return secondary_diagonal_count

func _count_center_subdivided_cells_for_shell_quad(shell_quad_state: Resource, shell_patch_states: Array) -> int:
	if shell_quad_state == null or shell_patch_states.is_empty():
		return 0
	var full_width_steps: int = maxi(shell_quad_state.width_voxels, 1)
	var full_height_steps: int = maxi(shell_quad_state.height_voxels, 1)
	var edge_u_step: Vector3 = shell_quad_state.edge_u_local / float(full_width_steps)
	var edge_v_step: Vector3 = shell_quad_state.edge_v_local / float(full_height_steps)
	_ensure_shell_quad_patch_offset_storage(shell_quad_state, shell_patch_states)
	var patch_offset_lookup: Dictionary = _build_shell_patch_offset_lookup(shell_quad_state)
	var changed_patch_coord_lookup: Dictionary = _build_changed_patch_coord_lookup(shell_quad_state)
	var localized_bounds: Dictionary = _resolve_localized_shell_patch_bounds(
		changed_patch_coord_lookup,
		full_width_steps,
		full_height_steps
	)
	var localized_shell_quad_state: Resource = _build_localized_shell_quad_state(
		shell_quad_state,
		localized_bounds,
		edge_u_step,
		edge_v_step
	)
	var localized_width_steps: int = int(localized_bounds.get("width", 0))
	var localized_height_steps: int = int(localized_bounds.get("height", 0))
	var vertex_grid: Array = _build_shell_vertex_grid(
		shell_quad_state,
		patch_offset_lookup,
		full_width_steps,
		full_height_steps,
		int(localized_bounds.get("start_u", 0)),
		int(localized_bounds.get("start_v", 0)),
		localized_width_steps,
		localized_height_steps,
		edge_u_step,
		edge_v_step
	)
	var vertex_normal_grid: Array = _build_shell_vertex_normal_grid(
		vertex_grid,
		localized_width_steps,
		localized_height_steps,
		localized_shell_quad_state.normal
	)
	var subdivided_cell_count: int = 0
	for v_index: int in range(localized_height_steps):
		for u_index: int in range(localized_width_steps):
			var vertex_a: Vector3 = vertex_grid[v_index][u_index]
			var vertex_b: Vector3 = vertex_grid[v_index + 1][u_index]
			var vertex_c: Vector3 = vertex_grid[v_index + 1][u_index + 1]
			var vertex_d: Vector3 = vertex_grid[v_index][u_index + 1]
			var resolved_normal: Vector3 = localized_shell_quad_state.normal.normalized()
			if resolved_normal == Vector3.ZERO:
				resolved_normal = (vertex_b - vertex_a).cross(vertex_d - vertex_a).normalized()
			if _is_cell_planar(vertex_a, vertex_b, vertex_c, vertex_d, resolved_normal):
				continue
			if _should_subdivide_shell_cell(
				vertex_a,
				vertex_b,
				vertex_c,
				vertex_d,
				vertex_normal_grid[v_index][u_index],
				vertex_normal_grid[v_index + 1][u_index],
				vertex_normal_grid[v_index + 1][u_index + 1],
				vertex_normal_grid[v_index][u_index + 1],
				localized_shell_quad_state.normal
			):
				subdivided_cell_count += 1
	return subdivided_cell_count

func _build_shell_vertex_normal_grid(
	vertex_grid: Array,
	width_steps: int,
	height_steps: int,
	expected_normal: Vector3
) -> Array:
	var vertex_normal_grid: Array = []
	for v_index: int in range(height_steps + 1):
		var row: Array = []
		for u_index: int in range(width_steps + 1):
			row.append(_resolve_shell_vertex_normal(vertex_grid, u_index, v_index, width_steps, height_steps, expected_normal))
		vertex_normal_grid.append(row)
	return vertex_normal_grid

func _resolve_shell_vertex_normal(
	vertex_grid: Array,
	u_index: int,
	v_index: int,
	width_steps: int,
	height_steps: int,
	expected_normal: Vector3
) -> Vector3:
	var current_vertex: Vector3 = vertex_grid[v_index][u_index]
	var left_vertex: Vector3 = vertex_grid[v_index][maxi(u_index - 1, 0)]
	var right_vertex: Vector3 = vertex_grid[v_index][mini(u_index + 1, width_steps)]
	var up_vertex: Vector3 = vertex_grid[maxi(v_index - 1, 0)][u_index]
	var down_vertex: Vector3 = vertex_grid[mini(v_index + 1, height_steps)][u_index]
	var tangent_u: Vector3 = right_vertex - left_vertex
	var tangent_v: Vector3 = down_vertex - up_vertex
	if tangent_u.is_zero_approx():
		tangent_u = right_vertex - current_vertex if not right_vertex.is_equal_approx(current_vertex) else current_vertex - left_vertex
	if tangent_v.is_zero_approx():
		tangent_v = down_vertex - current_vertex if not down_vertex.is_equal_approx(current_vertex) else current_vertex - up_vertex
	if tangent_u.is_zero_approx() or tangent_v.is_zero_approx():
		return expected_normal.normalized() if expected_normal != Vector3.ZERO else Vector3.UP
	var vertex_normal: Vector3 = tangent_u.cross(tangent_v).normalized()
	if vertex_normal == Vector3.ZERO:
		return expected_normal.normalized() if expected_normal != Vector3.ZERO else Vector3.UP
	var target_normal: Vector3 = expected_normal.normalized() if expected_normal != Vector3.ZERO else Vector3.ZERO
	if target_normal != Vector3.ZERO and vertex_normal.dot(target_normal) < 0.0:
		vertex_normal = -vertex_normal
	return vertex_normal

func _append_shell_boundary_wall_triangles(
	merged_geometry,
	vertex_grid: Array,
	width_steps: int,
	height_steps: int,
	shell_quad_state: Resource,
	edge_u_step: Vector3,
	edge_v_step: Vector3
) -> void:
	var baseline_u_min_points: Array = []
	var baseline_u_max_points: Array = []
	var current_u_min_points: Array = []
	var current_u_max_points: Array = []
	for v_index: int in range(height_steps + 1):
		baseline_u_min_points.append(shell_quad_state.origin_local + (edge_v_step * float(v_index)))
		baseline_u_max_points.append(shell_quad_state.origin_local + shell_quad_state.edge_u_local + (edge_v_step * float(v_index)))
		current_u_min_points.append(vertex_grid[v_index][0])
		current_u_max_points.append(vertex_grid[v_index][width_steps])
	_append_merged_wall_side_geometry(
		merged_geometry,
		baseline_u_min_points,
		current_u_min_points,
		shell_quad_state.material_variant_id
	)
	_append_merged_wall_side_geometry(
		merged_geometry,
		baseline_u_max_points,
		current_u_max_points,
		shell_quad_state.material_variant_id
	)
	var baseline_v_min_points: Array = []
	var baseline_v_max_points: Array = []
	var current_v_min_points: Array = []
	var current_v_max_points: Array = []
	for u_index: int in range(width_steps + 1):
		baseline_v_min_points.append(shell_quad_state.origin_local + (edge_u_step * float(u_index)))
		baseline_v_max_points.append(shell_quad_state.origin_local + shell_quad_state.edge_v_local + (edge_u_step * float(u_index)))
		current_v_min_points.append(vertex_grid[0][u_index])
		current_v_max_points.append(vertex_grid[height_steps][u_index])
	_append_merged_wall_side_geometry(
		merged_geometry,
		baseline_v_min_points,
		current_v_min_points,
		shell_quad_state.material_variant_id
	)
	_append_merged_wall_side_geometry(
		merged_geometry,
		baseline_v_max_points,
		current_v_max_points,
		shell_quad_state.material_variant_id
	)

func _append_merged_wall_side_geometry(
	merged_geometry,
	baseline_points: Array,
	current_points: Array,
	material_variant_id: StringName
) -> void:
	var segment_count: int = mini(baseline_points.size(), current_points.size()) - 1
	var segment_index: int = 0
	while segment_index < segment_count:
		if _is_wall_segment_unchanged(baseline_points, current_points, segment_index):
			segment_index += 1
			continue
		var end_index: int = segment_index + 1
		while end_index < segment_count and _can_extend_wall_region(
			baseline_points,
			current_points,
			segment_index,
			end_index + 1
		):
			end_index += 1
		_append_wall_region_geometry(
			merged_geometry,
			baseline_points[segment_index],
			baseline_points[end_index],
			current_points[segment_index],
			current_points[end_index],
			material_variant_id,
			end_index - segment_index
		)
		segment_index = end_index

func _is_wall_segment_unchanged(
	baseline_points: Array,
	current_points: Array,
	segment_index: int
) -> bool:
	return (
		baseline_points[segment_index].is_equal_approx(current_points[segment_index])
		and baseline_points[segment_index + 1].is_equal_approx(current_points[segment_index + 1])
	)

func _can_extend_wall_region(
	baseline_points: Array,
	current_points: Array,
	start_index: int,
	proposed_end_index: int
) -> bool:
	if _is_wall_segment_unchanged(baseline_points, current_points, proposed_end_index - 1):
		return false
	var baseline_start: Vector3 = baseline_points[start_index]
	var baseline_end: Vector3 = baseline_points[proposed_end_index]
	var current_start: Vector3 = current_points[start_index]
	var current_end: Vector3 = current_points[proposed_end_index]
	if not _can_build_planar_wall_quad(
		baseline_start,
		baseline_end,
		current_start,
		current_end
	):
		return false
	for point_index: int in range(start_index + 1, proposed_end_index):
		if not _point_lies_on_segment_line(
			current_points[point_index],
			current_start,
			current_end
		):
			return false
	return true

func _can_build_planar_wall_quad(
	baseline_start: Vector3,
	baseline_end: Vector3,
	current_start: Vector3,
	current_end: Vector3
) -> bool:
	var baseline_direction: Vector3 = baseline_end - baseline_start
	var current_direction: Vector3 = current_end - current_start
	if baseline_direction.is_zero_approx() or current_direction.is_zero_approx():
		return false
	if not current_direction.is_equal_approx(baseline_direction):
		return false
	var quad_normal: Vector3 = baseline_direction.cross(current_start - baseline_start).normalized()
	if quad_normal == Vector3.ZERO:
		return false
	return _is_cell_planar(
		baseline_start,
		baseline_end,
		current_end,
		current_start,
		quad_normal
	)

func _point_lies_on_segment_line(
	test_point: Vector3,
	line_start: Vector3,
	line_end: Vector3
) -> bool:
	var line_direction: Vector3 = line_end - line_start
	if line_direction.is_zero_approx():
		return test_point.is_equal_approx(line_start)
	var point_direction: Vector3 = test_point - line_start
	return point_direction.cross(line_direction).is_zero_approx()

func _append_wall_region_geometry(
	merged_geometry,
	baseline_start: Vector3,
	baseline_end: Vector3,
	current_start: Vector3,
	current_end: Vector3,
	material_variant_id: StringName,
	segment_span: int
) -> void:
	if _can_build_planar_wall_quad(
		baseline_start,
		baseline_end,
		current_start,
		current_end
	):
		var surface_quad = CraftedItemCanonicalSurfaceQuadScript.new()
		surface_quad.origin_local = baseline_start
		surface_quad.edge_u_local = baseline_end - baseline_start
		surface_quad.edge_v_local = current_start - baseline_start
		var quad_normal: Vector3 = surface_quad.edge_u_local.cross(surface_quad.edge_v_local).normalized()
		if quad_normal == Vector3.ZERO:
			return
		surface_quad.normal = quad_normal
		surface_quad.material_variant_id = material_variant_id
		surface_quad.width_voxels = maxi(segment_span, 1)
		surface_quad.height_voxels = 1
		merged_geometry.surface_quads.append(surface_quad)
		return
	_append_wall_strip_triangles(
		merged_geometry,
		baseline_start,
		baseline_end,
		current_start,
		current_end,
		material_variant_id
	)

func _append_wall_strip_triangles(
	merged_geometry,
	baseline_start: Vector3,
	baseline_end: Vector3,
	current_start: Vector3,
	current_end: Vector3,
	material_variant_id: StringName
) -> void:
	if baseline_start.is_equal_approx(current_start) and baseline_end.is_equal_approx(current_end):
		return
	_append_surface_triangle(
		merged_geometry,
		baseline_start,
		current_start,
		current_end,
		material_variant_id
	)
	_append_surface_triangle(
		merged_geometry,
		baseline_start,
		current_end,
		baseline_end,
		material_variant_id
	)

func _append_surface_triangle(
	merged_geometry,
	vertex_a: Vector3,
	vertex_b: Vector3,
	vertex_c: Vector3,
	material_variant_id: StringName,
	expected_normal: Vector3 = Vector3.ZERO,
	vertex_a_normal: Vector3 = Vector3.ZERO,
	vertex_b_normal: Vector3 = Vector3.ZERO,
	vertex_c_normal: Vector3 = Vector3.ZERO
) -> void:
	var edge_ab: Vector3 = vertex_b - vertex_a
	var edge_ac: Vector3 = vertex_c - vertex_a
	if edge_ab.is_zero_approx() or edge_ac.is_zero_approx():
		return
	var resolved_normal: Vector3 = edge_ab.cross(edge_ac).normalized()
	if resolved_normal == Vector3.ZERO:
		return
	var final_vertex_b: Vector3 = vertex_b
	var final_vertex_c: Vector3 = vertex_c
	var final_vertex_b_normal: Vector3 = vertex_b_normal
	var final_vertex_c_normal: Vector3 = vertex_c_normal
	if expected_normal != Vector3.ZERO and resolved_normal.dot(expected_normal.normalized()) < 0.0:
		final_vertex_b = vertex_c
		final_vertex_c = vertex_b
		final_vertex_b_normal = vertex_c_normal
		final_vertex_c_normal = vertex_b_normal
		resolved_normal = ((final_vertex_b - vertex_a).cross(final_vertex_c - vertex_a)).normalized()
		if resolved_normal == Vector3.ZERO:
			return
	var surface_triangle = CraftedItemCanonicalSurfaceTriangleScript.new()
	surface_triangle.vertex_a_local = vertex_a
	surface_triangle.vertex_b_local = final_vertex_b
	surface_triangle.vertex_c_local = final_vertex_c
	surface_triangle.normal = resolved_normal
	surface_triangle.vertex_a_normal = vertex_a_normal.normalized() if vertex_a_normal != Vector3.ZERO else Vector3.ZERO
	surface_triangle.vertex_b_normal = final_vertex_b_normal.normalized() if final_vertex_b_normal != Vector3.ZERO else Vector3.ZERO
	surface_triangle.vertex_c_normal = final_vertex_c_normal.normalized() if final_vertex_c_normal != Vector3.ZERO else Vector3.ZERO
	surface_triangle.material_variant_id = material_variant_id
	merged_geometry.surface_triangles.append(surface_triangle)
