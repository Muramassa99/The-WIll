extends RefCounted
class_name CraftedItemCanonicalSurfaceQuad

var origin_local: Vector3 = Vector3.ZERO
var edge_u_local: Vector3 = Vector3.ZERO
var edge_v_local: Vector3 = Vector3.ZERO
var normal: Vector3 = Vector3.ZERO
var material_variant_id: StringName = &""
var width_voxels: int = 0
var height_voxels: int = 0
var stage2_face_id: StringName = &""
var stage2_target_kind: StringName = &""
var stage2_shell_quad_id: StringName = &""
var stage2_patch_ids: PackedStringArray = PackedStringArray()

func get_vertices() -> Array[Vector3]:
	if normal.dot(edge_u_local.cross(edge_v_local)) >= 0.0:
		return [
			origin_local,
			origin_local + edge_v_local,
			origin_local + edge_u_local + edge_v_local,
			origin_local + edge_u_local
		]
	return [
		origin_local,
		origin_local + edge_u_local,
		origin_local + edge_u_local + edge_v_local,
		origin_local + edge_v_local
	]
