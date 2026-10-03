extends RefCounted

## Read-only bridge from the saved Forge Stage2 resource to a held weapon.
## Handle cells convert once to WeaponRootOrigin meters. Saved target vertices
## are already meters and are never rebuilt or offset here.
const Packet = preload("res://core/resolvers/primary_grip_handle_mesh_packet.gd")
const META := &"saved_wrapper_grip_source"
const SOURCE_ORIGIN := &"ForgeSavedGripSourceOrigin"

static func from_stage2(stage: Resource, source_to_weapon: Transform3D) -> Dictionary:
	if stage == null: return {"valid":false,"reason":"missing_saved_stage2"}
	if not source_to_weapon.is_finite() or not source_to_weapon.basis.is_equal_approx(Basis.IDENTITY):
		return {"valid":false,"reason":"invalid_equipped_source_rebase"}
	if stage.get("primary_grip_handle_mesh_source") != Packet.SOURCE or stage.get("primary_grip_handle_mesh_origin_id") != Packet.VERTICES_ORIGIN_ID:
		return {"valid":false,"reason":"missing_named_saved_handle_source"}
	var wrapper: Resource = stage.get("primary_grip_target_wrapper")
	if wrapper == null: return {"valid":false,"reason":"saved_weapon_requires_forge_wrapper_save"}
	var mesh: Resource = stage.get("primary_grip_handle_mesh_state")
	var cell: float = float(stage.get("cell_world_size_meters"))
	if mesh == null or not is_finite(cell) or cell <= 0.0:
		return {"valid":false,"reason":"missing_saved_handle_mesh_or_metric"}
	var arrays: Array = mesh.get("surface_arrays")
	if arrays.size() != Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or not arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		return {"valid":false,"reason":"invalid_saved_handle_arrays"}
	var vertices := PackedVector3Array()
	for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]: vertices.append(point * cell)
	var packet := Packet.build(vertices, arrays[Mesh.ARRAY_INDEX], str(stage.get("primary_grip_handle_body_signature")))
	var checked := Packet.validate(packet)
	if not checked.get("valid",false): return {"valid":false,"reason":"invalid_saved_handle_packet","detail":checked}
	return {"valid":true,"wrapper":wrapper.duplicate(true),"handle_packet":packet,
		"origin_id":Packet.VERTICES_ORIGIN_ID,"metric_units":&"meters",
		"source_origin_id":SOURCE_ORIGIN,"source_to_weapon":source_to_weapon,
		"source_parent_origin_id":Packet.VERTICES_ORIGIN_ID,
		"source_body_signature":checked.body_signature,"wrapper_generation_ran":false}
