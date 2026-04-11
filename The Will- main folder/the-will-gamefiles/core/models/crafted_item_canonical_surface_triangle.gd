extends RefCounted
class_name CraftedItemCanonicalSurfaceTriangle

var vertex_a_local: Vector3 = Vector3.ZERO
var vertex_b_local: Vector3 = Vector3.ZERO
var vertex_c_local: Vector3 = Vector3.ZERO
var normal: Vector3 = Vector3.ZERO
var vertex_a_normal: Vector3 = Vector3.ZERO
var vertex_b_normal: Vector3 = Vector3.ZERO
var vertex_c_normal: Vector3 = Vector3.ZERO
var material_variant_id: StringName = &""
var stage2_face_id: StringName = &""
var stage2_target_kind: StringName = &""
var stage2_shell_quad_id: StringName = &""
var stage2_patch_ids: PackedStringArray = PackedStringArray()

func get_vertices() -> Array[Vector3]:
	return [
		vertex_a_local,
		vertex_b_local,
		vertex_c_local,
	]

func has_vertex_normals() -> bool:
	return (
		vertex_a_normal != Vector3.ZERO
		and vertex_b_normal != Vector3.ZERO
		and vertex_c_normal != Vector3.ZERO
	)
