extends Resource
class_name Stage2ItemState

const CraftedItemCanonicalGeometryScript = preload("res://core/models/crafted_item_canonical_geometry.gd")

@export var stage2_version: int = 1
@export var source_wip_id: StringName = &""
@export var source_stage1_cell_count: int = 0
@export var cell_world_size_meters: float = 0.025
@export var baseline_local_aabb_position: Vector3 = Vector3.ZERO
@export var baseline_local_aabb_size: Vector3 = Vector3.ZERO
@export var current_local_aabb_position: Vector3 = Vector3.ZERO
@export var current_local_aabb_size: Vector3 = Vector3.ZERO
@export var patch_states: Array[Resource] = []
@export var refinement_initialized: bool = false
@export var dirty: bool = false
@export var last_active_tool_id: StringName = &""

func has_current_shell() -> bool:
	return refinement_initialized and not patch_states.is_empty()

func get_patch_count() -> int:
	return patch_states.size()

func build_current_canonical_geometry(source_solid = null):
	return _build_current_canonical_geometry_internal(source_solid)

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

func _build_current_canonical_geometry_internal(source_solid = null, patch_id_lookup: Dictionary = {}):
	var canonical_geometry = CraftedItemCanonicalGeometryScript.new()
	canonical_geometry.source_solid = source_solid
	canonical_geometry.local_aabb = AABB(current_local_aabb_position, current_local_aabb_size)
	if not has_current_shell():
		return canonical_geometry
	for patch_state in patch_states:
		if patch_state == null or not patch_state.has_current_quad():
			continue
		if not patch_id_lookup.is_empty() and not patch_id_lookup.has(patch_state.patch_id):
			continue
		canonical_geometry.surface_quads.append(patch_state.current_quad.build_canonical_surface_quad())
	return canonical_geometry

func refresh_current_local_aabb_from_patches() -> void:
	if not has_current_shell():
		current_local_aabb_position = baseline_local_aabb_position
		current_local_aabb_size = baseline_local_aabb_size
		return
	var has_vertex: bool = false
	var min_vertex: Vector3 = Vector3.ZERO
	var max_vertex: Vector3 = Vector3.ZERO
	for patch_state in patch_states:
		if patch_state == null or not patch_state.has_current_quad():
			continue
		var surface_quad = patch_state.current_quad.build_canonical_surface_quad()
		for vertex: Vector3 in surface_quad.get_vertices():
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
