extends Resource
class_name Stage2ShellQuadState

const CraftedItemCanonicalSurfaceQuadScript = preload("res://core/models/crafted_item_canonical_surface_quad.gd")

@export var origin_local: Vector3 = Vector3.ZERO
@export var edge_u_local: Vector3 = Vector3.ZERO
@export var edge_v_local: Vector3 = Vector3.ZERO
@export var normal: Vector3 = Vector3.ZERO
@export var material_variant_id: StringName = &""
@export var shell_quad_id: StringName = &""
@export var width_voxels: int = 0
@export var height_voxels: int = 0
@export var vertex_keys: PackedStringArray = PackedStringArray()
@export var patch_offset_cells: PackedFloat32Array = PackedFloat32Array()
@export var vertex_offset_cells: PackedFloat32Array = PackedFloat32Array()
@export var dirty: bool = false

func build_canonical_surface_quad():
	var surface_quad = CraftedItemCanonicalSurfaceQuadScript.new()
	surface_quad.origin_local = origin_local
	surface_quad.edge_u_local = edge_u_local
	surface_quad.edge_v_local = edge_v_local
	surface_quad.normal = normal
	surface_quad.material_variant_id = material_variant_id
	surface_quad.width_voxels = width_voxels
	surface_quad.height_voxels = height_voxels
	surface_quad.stage2_face_id = shell_quad_id
	surface_quad.stage2_target_kind = &"surface_face"
	surface_quad.stage2_shell_quad_id = shell_quad_id
	return surface_quad
