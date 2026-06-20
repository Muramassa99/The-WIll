extends Resource
class_name Stage2ShellMeshState

const CraftedItemCanonicalGeometryScript = preload("res://core/models/crafted_item_canonical_geometry.gd")
const Stage2ShellQuadStateScript = preload("res://core/models/stage2_shell_quad_state.gd")

@export var shell_quads: Array[Resource] = []
@export var shared_vertex_keys: PackedStringArray = PackedStringArray()
@export var shared_vertex_baseline_positions_local: PackedVector3Array = PackedVector3Array()
@export var shared_vertex_current_positions_local: PackedVector3Array = PackedVector3Array()
@export var local_aabb_position: Vector3 = Vector3.ZERO
@export var local_aabb_size: Vector3 = Vector3.ZERO
@export var dirty: bool = false

func has_shell_geometry() -> bool:
	return not shell_quads.is_empty()

func get_quad_count() -> int:
	return shell_quads.size()

func build_canonical_geometry(source_solid = null):
	var canonical_geometry = CraftedItemCanonicalGeometryScript.new()
	canonical_geometry.source_solid = source_solid
	canonical_geometry.local_aabb = AABB(local_aabb_position, local_aabb_size)
	for quad_state: Resource in shell_quads:
		if quad_state == null:
			continue
		canonical_geometry.surface_quads.append(quad_state.build_canonical_surface_quad())
	return canonical_geometry

func copy_from_canonical_geometry(canonical_geometry) -> void:
	shell_quads.clear()
	if canonical_geometry == null:
		local_aabb_position = Vector3.ZERO
		local_aabb_size = Vector3.ZERO
		shared_vertex_keys = PackedStringArray()
		shared_vertex_baseline_positions_local = PackedVector3Array()
		shared_vertex_current_positions_local = PackedVector3Array()
		dirty = false
		return
	local_aabb_position = canonical_geometry.local_aabb.position
	local_aabb_size = canonical_geometry.local_aabb.size
	shared_vertex_keys = PackedStringArray()
	shared_vertex_baseline_positions_local = PackedVector3Array()
	shared_vertex_current_positions_local = PackedVector3Array()
	for surface_quad in canonical_geometry.surface_quads:
		if surface_quad == null:
			continue
		var quad_state = Stage2ShellQuadStateScript.new()
		quad_state.origin_local = surface_quad.origin_local
		quad_state.edge_u_local = surface_quad.edge_u_local
		quad_state.edge_v_local = surface_quad.edge_v_local
		quad_state.normal = surface_quad.normal
		quad_state.material_variant_id = surface_quad.material_variant_id
		quad_state.width_voxels = surface_quad.width_voxels
		quad_state.height_voxels = surface_quad.height_voxels
		shell_quads.append(quad_state)
	dirty = false
